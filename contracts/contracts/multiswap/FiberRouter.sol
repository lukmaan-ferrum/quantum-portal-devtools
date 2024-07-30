// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.24;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
// import { MessagingFee, OFTReceipt, SendParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
// import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
// import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
// import { IStargate, Ticket } from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
// import "./common/SafeAmount.sol";
// import "./common/its/interfaces/IInterchainTokenService.sol";
// import "./common/its/interfaces/IInterchainTokenStandard.sol";
// import "./common/its/InterchainTokenExecutable.sol";
// import "./quantum-portal/IQuantumPortalPoc.sol";
// import "./Pool.sol";
// import "hardhat/console.sol";


// contract FiberRouter is Ownable, ReentrancyGuard, InterchainTokenExecutable {
//     using SafeERC20 for IERC20;
//     using OptionsBuilder for bytes;
//     address private constant NATIVE_CURRENCY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
//     address public pool;
//     address payable public gasWallet;
//     IQuantumPortalPoc public portal;
//     address public immutable lzEndpoint;
//     IStargate public stargate;

//     mapping(uint256 => TrustedRemote) public trustedRemotes;            // remoteChainId => { remoteFiberRouter; remotePool }
//     mapping(address => mapping(uint256 => address)) public tokenPaths;  // sourceToken => remoteChainId => remoteToken
//     mapping(bytes32 => bool) private routerAllowList;                   // 0x{4byteFuncSelector}0000000000000000{20byteRouterAddress} => isAllowed
//     mapping(uint256 => uint32) public chainIdToLzEid;                  // chainId => lzEid
//     mapping(uint32 => uint256) public lzEidToChainId;                  // lzEid => chainId

//     struct TrustedRemote {
//         address router;
//         address pool;
//     }

//     event InitiateCross(
//         address sourceFoundryToken,
//         uint256 amountIn,
//         address remoteFoundryToken,
//         address recipient,
//         uint256 targetChainId,
//         uint256 gasFee
//     );

//     event SwapAndInitiateCross(
//         address fromToken,
//         uint256 amountIn,
//         address sourceFoundryToken,
//         uint256 amountOut,
//         address remoteFoundryToken,
//         address recipient,
//         uint256 targetChainId,
//         uint256 gasFee
//     );

//     event FinalizeCross(
//         address token,
//         uint256 amount,
//         address receipient,
//         uint64 srcChainId
//     );

//     event ITSTransferFailed(
//         address token,
//         uint256 amount,
//         address recipient
//     );

//     event RouterAndSelectorWhitelisted(address router, bytes4 selector);
//     event RouterAndSelectorRemoved(address router, bytes selector);

//     modifier onlyPortal() {
//         require(msg.sender == address(portal), "FR: Caller is not the portal");
//         _;
//     }

//     constructor(
//         address _portal,
//         address payable _gasWallet,
//         address interchainTokenService,
//         address _lzEndpoint,
//         address _stargate
//     ) Ownable(msg.sender) InterchainTokenExecutable(interchainTokenService) {
//         require(_portal != address(0), "Quantum portal address cannot be zero");
//         require(_gasWallet != address(0), "Gas wallet address cannot be zero");
//         require(_lzEndpoint != address(0), "LZ endpoint address cannot be zero");
//         require(_stargate != address(0), "Stargate address cannot be zero");

//         portal = IQuantumPortalPoc(_portal);
//         gasWallet = _gasWallet;
//         lzEndpoint = _lzEndpoint;
//         stargate = IStargate(_stargate);
//     }

//     //#############################################################
//     //###################### USER FUNCTIONS #######################
//     //#############################################################
//     function initiateCross(
//         address sourceFoundryToken,
//         uint256 amountIn,
//         address recipient,
//         uint64 targetChainId,
//         uint256 swapType
//     ) external payable {
//         require(amountIn > 0, "FR: Amount in must be greater than zero");
//         require(recipient != address(0), "FR: Recipient address cannot be zero");
//         require(msg.value > 0, "FR: Remote gas fee must be greater than zero");

//         address remoteFoundryToken = _getAndCheckRemoteFoundryToken(sourceFoundryToken, targetChainId);
//         _callBridgingService(sourceFoundryToken, remoteFoundryToken, amountIn, recipient, targetChainId, swapType);

//         emit InitiateCross(
//             sourceFoundryToken,
//             amountIn,
//             remoteFoundryToken,
//             recipient,
//             targetChainId,
//             msg.value
//         );
//     }

//     function swapTokensAndInitiateCross(
//         address fromToken,
//         address sourceFoundryToken,
//         uint256 amountIn,
//         uint256 minAmountOut,
//         address router,
//         bytes calldata routerCalldata,
//         address recipient,
//         uint64 targetChainId,
//         uint256 swapType
//     ) external payable {
//         _moveTokens(fromToken, msg.sender, address(this), amountIn);
//         uint256 amountOut = _swapAndCheckSlippage(
//             swapType == 0 ? address(this) : pool,
//             fromToken,
//             sourceFoundryToken,
//             amountIn,
//             minAmountOut,
//             router,
//             routerCalldata
//         );

//         address remoteFoundryToken = _getAndCheckRemoteFoundryToken(sourceFoundryToken, targetChainId);
//         _callBridgingService(sourceFoundryToken, remoteFoundryToken, amountOut, recipient, targetChainId, swapType);

//         emit SwapAndInitiateCross(
//             fromToken,
//             amountIn,
//             sourceFoundryToken,
//             amountOut,
//             remoteFoundryToken,
//             recipient,
//             targetChainId,
//             msg.value
//         );
//     }

//     function finalizeCross(
//         address token,
//         address recipient,
//         uint256 amount
//     ) public virtual nonReentrant onlyPortal {
//         require(token != address(0), "FR: Token address cannot be zero");
//         require(recipient != address(0), "FR: Payee address cannot be zero");
//         require(amount != 0, "FR: Amount must be greater than zero");

//         (uint256 sourceChainId, address sourceRouter,) = portal.msgSender();
//         require(trustedRemotes[sourceChainId].router == sourceRouter, "FR: Router not trusted");
//         Pool(pool).finalizeCross(token, recipient, amount);

//         emit FinalizeCross(
//             token,
//             amount,
//             recipient,
//             uint64(sourceChainId)
//         );
//     }

//     //#############################################################
//     //###################### ADMIN FUNCTIONS ######################
//     //#############################################################
//     /**
//      * @dev Sets the fund manager contract.
//      * @param _pool The fund manager
//      */
//     function setPool(address _pool) external onlyOwner {
//         require(_pool != address(0), "Swap pool address cannot be zero");
//         pool = _pool;
//     }

//     /**
//      * @dev Sets the gas wallet address.
//      * @param _gasWallet The wallet which pays for the funds on withdrawal
//      */
//     function setGasFeeWallet(address payable _gasWallet) external onlyOwner {
//         require(_gasWallet != address(0), "FR: Gas Wallet address cannot be zero");
//         gasWallet = _gasWallet;
//     }

//     function addTrustedRemotes(
//         uint256[] calldata remoteChainIds,
//         address[] calldata remoteRouters,
//         address[] calldata remotePools
//     ) external onlyOwner {
//         require(remoteChainIds.length == remoteRouters.length && remoteChainIds.length == remotePools.length, "FR: Array length mismatch");
//         for (uint256 i = 0; i < remoteChainIds.length; i++) {
//             require(remoteChainIds[i] != 0, "FR: Chain ID cannot be zero");
//             require(remoteRouters[i] != address(0), "FR: Remote fiber router address cannot be zero");
//             require(remotePools[i] != address(0), "FR: Remote pool address cannot be zero");
//             trustedRemotes[remoteChainIds[i]] = TrustedRemote({
//                 router: remoteRouters[i],
//                 pool: remotePools[i]
//             });
//         }
//     }

//     function removeTrustedRemotes(address[] calldata srcFoundryTokens, uint256[] calldata chainIds) external onlyOwner {
//         require(chainIds.length == srcFoundryTokens.length, "FR: Array length mismatch");
//         for (uint256 i = 0; i < chainIds.length; i++) {
//             delete trustedRemotes[chainIds[i]];
//         }
//     }

//     function addTokenPaths(
//         address[] calldata sourceTokens,
//         uint256[] calldata remoteChainIds,
//         address[] calldata remoteTokens
//     ) external onlyOwner {
//         require(sourceTokens.length == remoteChainIds.length && sourceTokens.length == remoteTokens.length, "FR: Array length mismatch");
//         for (uint256 i = 0; i < sourceTokens.length; i++) {
//             tokenPaths[sourceTokens[i]][remoteChainIds[i]] = remoteTokens[i];
//         }
//     }

//     function removeTokenPaths(address[] calldata sourceTokens, uint256[] calldata remoteChainIds) external onlyOwner {
//         require(sourceTokens.length == remoteChainIds.length, "FR: Array length mismatch");
//         for (uint256 i = 0; i < sourceTokens.length; i++) {
//             delete tokenPaths[sourceTokens[i]][remoteChainIds[i]];
//         }
//     }

//     /**
//      * @notice Whitelists the router and selector combination
//      * @param router The router address
//      * @param selectors The selectors for the router
//      */
//     function addRouterAndSelectors(address router, bytes4[] memory selectors) external onlyOwner {
//         for (uint256 i = 0; i < selectors.length; i++) {
//             routerAllowList[_getKey(router, abi.encodePacked(selectors[i]))] = true;
//             emit RouterAndSelectorWhitelisted(router, selectors[i]);
//         }
//     }

//     /**
//      * @notice Removes the router and selector combination from the whitelist
//      * @param router The router address
//      * @param selector The selector for the router
//      */
//     function removeRouterAndSelector(address router, bytes calldata selector) external onlyOwner {
//         routerAllowList[_getKey(router, selector)] = false;
//         emit RouterAndSelectorRemoved(router, selector);
//     }

//     //#############################################################
//     //###################### VIEW FUNCTIONS #######################
//     //#############################################################
//     /**
//      * @notice Checks if the router and selector combination is whitelisted
//      * @param router The router address
//      * @param selector The selector for the router
//      */
//     function isAllowListed(address router, bytes memory selector) public view returns (bool) {
//         return routerAllowList[_getKey(router, selector)];
//     }

//     //#############################################################
//     //##################### INTERNAL FUNCTIONS ####################
//     //#############################################################
//     function _getAndCheckRemoteFoundryToken(address token, uint64 targetChainId) internal view returns (address) {
//         address remoteFoundryToken = tokenPaths[token][targetChainId];
//         require(remoteFoundryToken != address(0), "FR: Token path not found");
//         return remoteFoundryToken;
//     }

//     function _moveTokens(
//         address token,
//         address from,
//         address to,
//         uint256 amount
//     ) internal {
//         if (from == address(this)) {
//             IERC20(token).safeTransfer(to, amount);
//         } else {
//             IERC20(token).safeTransferFrom(from, to, amount);
//         }
//     }

//     function _callBridgingService(
//         address token,
//         address remoteFoundryToken,
//         uint256 amount,
//         address recipient,
//         uint64 targetChainId,
//         uint256 swapType
//     ) internal {
//         if (swapType == 0) { // Portal
//             _moveTokens(token, msg.sender, pool, amount);
//             amount = Pool(pool).initiateCross(token);
//             console.log("amount: %s", amount);
//             SafeAmount.safeTransferETH(gasWallet, msg.value);

//             portal.run(targetChainId, trustedRemotes[targetChainId].router, recipient, abi.encodeWithSelector(
//                 this.finalizeCross.selector,
//                 remoteFoundryToken,
//                 recipient,
//                 amount
//             ));
//         } else if (swapType == 1) { // Interchain Token Service (Axelar)
//             IInterchainTokenService(interchainTokenService).callContractWithInterchainToken(
//                 IInterchainTokenStandard(remoteFoundryToken).interchainTokenId(),
//                 _getChainName(targetChainId),
//                 _toBytes(trustedRemotes[targetChainId].router),
//                 amount,
//                 abi.encode(recipient),
//                 msg.value
//             );
//         } else if (swapType == 2) { // Stargate + LayerZero
//             uint256 valueToSend;
//             SendParam memory sendParam;
//             MessagingFee memory messagingFee;
//             uint32 _dstEid = chainIdToLzEid[targetChainId];
//             address _composer = trustedRemotes[targetChainId].router;
//             bytes memory _composeMsg = abi.encode(recipient, token);

//             (valueToSend, sendParam, messagingFee) = _prepareTakeTaxi(_dstEid, amount, _composer, _composeMsg);

//             _moveTokens(token, msg.sender, address(this), amount);
//             IERC20(token).approve(address(stargate), amount);

//             stargate.sendToken{ value: valueToSend }(sendParam, messagingFee, msg.sender);
//         } else {
//             revert("FR: Invalid swap type");
//         }
//     }

//     function _getBalance(address token, address account) private view returns (uint256) {
//         return token == NATIVE_CURRENCY ? account.balance : IERC20(token).balanceOf(account);
//     }

//     function _approveAggregatorRouter(address token, address router, uint256 amount) private {
//         uint256 currentAllowance = IERC20(token).allowance(address(this), router);
//         if (currentAllowance > 0) {
//             IERC20(token).safeDecreaseAllowance(router, currentAllowance);
//         }
//         IERC20(token).safeIncreaseAllowance(router, amount);
//     }

//     function _getKey(address router, bytes memory data) private pure returns (bytes32) {
//         bytes32 key; // Takes the shape of 0x{4byteFuncSelector}00..00{20byteRouterAddress}
//         assembly {
//             key := or(
//                 and(mload(add(data, 0x20)), 0xffffffff00000000000000000000000000000000000000000000000000000000),
//                 router
//             )
//         }
//         return key;
//     }

//     function _swapAndCheckSlippage(
//         address targetAddress,
//         address fromToken,
//         address toToken,
//         uint256 amountIn,
//         uint256 minAmountOut,
//         address router,
//         bytes memory data
//     ) internal returns (uint256) {
//         require(isAllowListed(router, data), "FR: Router and selector not whitelisted");
//         _approveAggregatorRouter(fromToken, router, amountIn);
//         uint256 balanceBefore = _getBalance(toToken, targetAddress);
//         console.log("before makeRouterCall");
//         console.log(balanceBefore);
//         _makeRouterCall(router, data);
//         uint256 amountOut = _getBalance(toToken, targetAddress) - balanceBefore;
//         console.log("right after makeRouterCall");
//         console.log(amountOut);

//         require(amountOut >= minAmountOut, "FR: Slippage check failed");

//         return amountOut;
//     }

//     function _makeRouterCall(address router, bytes memory data) private {
//         (bool success, bytes memory returnData) = router.call(data);
//         if (!success) {
//             if (returnData.length > 0) { // Bubble up the revert reason
//                 assembly {
//                     let returnDataSize := mload(returnData)
//                     revert(add(32, returnData), returnDataSize)
//                 }
//             } else {
//                 revert("FR: Call to router failed");
//             }
//         }
//     }

//     function _prepareTakeTaxi(
//         uint32 _dstEid,
//         uint256 _amount,
//         address _composer,
//         bytes memory _composeMsg
//     ) internal view returns (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) {
//         bytes memory extraOptions = _composeMsg.length > 0
//             ? OptionsBuilder.newOptions().addExecutorLzComposeOption(0, 200_000, 0) // compose gas limit
//             : bytes("");

//         sendParam = SendParam({
//             dstEid: _dstEid,
//             to: bytes32(_toBytes(_composer)),
//             amountLD: _amount,
//             minAmountLD: _amount,
//             extraOptions: extraOptions,
//             composeMsg: _composeMsg,
//             oftCmd: ""
//         });

//         (, , OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);
//         sendParam.minAmountLD = receipt.amountReceivedLD;

//         messagingFee = stargate.quoteSend(sendParam, false);
//         valueToSend = messagingFee.nativeFee;

//         if (stargate.token() == address(0x0)) {
//             valueToSend += sendParam.amountLD;
//         }
//     }

//     function _executeWithInterchainToken(
//         bytes32, // commandId, unusued
//         string calldata sourceChain,
//         bytes calldata sourceAddress,
//         bytes calldata data,
//         bytes32, // tokenId, unused
//         address token,
//         uint256 amount
//     ) internal override {
//         require(trustedRemotes[_getChainId(sourceChain)].router == _toAddress(sourceAddress), "FR: Router not trusted");

//         if (data.length == 0x20) { // Simple bridging
//             address recipient = abi.decode(data, (address));
//             _moveTokens(token, address(this), recipient, amount);
//         } else if (data.length > 0x20) { // TODO: Implement finalizeCross + Swap
//             (address recipient, bytes memory oneInchCalldata) = abi.decode(data, (address, bytes)); // There's also 4 more: minAmountOut, targetToken, router, routerCalldata
//         } else {
//             revert("FR: Invalid data length");
//         }
//     }

//     function lzCompose(
//         address _from,
//         bytes32, // guid
//         bytes calldata _message,
//         address, // lz executor
//         bytes calldata // extraData
//     ) external payable {
//         require(_from == address(stargate), "!stargate");
//         require(msg.sender == lzEndpoint, "!endpoint");
//         uint256 sourceChainId = lzEidToChainId[OFTComposeMsgCodec.srcEid(_message)];
//         require(trustedRemotes[sourceChainId].router == _from, "FR: Router not trusted");

//         uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
//         bytes memory data = OFTComposeMsgCodec.composeMsg(_message);
        
//         if (data.length == 0x40) {
//             (address recipient, address token) = abi.decode(data, (address, address));
//             _moveTokens(token, address(this), recipient, amountLD);
//         } else if (data.length > 0x40) {
//             (address recipient, address token, bytes memory oneInchCalldata) = abi.decode(data, (address, address, bytes)); // There's also 4 more: minAmountOut, targetToken, router, routerCalldata
//         } else {
//             revert("FR: Invalid data length");
//         }
//     }
// }
