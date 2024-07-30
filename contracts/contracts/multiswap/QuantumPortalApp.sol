// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseRouter } from "./BaseRouter.sol";
import { IQuantumPortalPoc } from "./quantum-portal/IQuantumPortalPoc.sol";
import { WithQp } from "../quantumPortal/poc/utils/WithQp.sol";
import { WithRemotePeers } from "../quantumPortal/poc/utils/WithRemotePeers.sol";
import "hardhat/console.sol";

abstract contract QuantumPortalApp is BaseRouter, WithQp, WithRemotePeers {

    modifier onlyPortal() {
        require(msg.sender == address(portal), "QPApp: Caller is not the portal");
        _;
    }

    constructor(address _portal) {
        _initializeWithQp(_portal);
    }

    function finalizeCross(
        address token,
        address recipient,
        uint256 amount
    ) public onlyPortal {
        require(token != address(0), "FR: Token address cannot be zero");
        require(recipient != address(0), "FR: Payee address cannot be zero");
        require(amount != 0, "FR: Amount must be greater than zero");
        
        (uint256 sourceChainId, address sourceRouter,) = portal.msgSender();
        require(trustedRemoteRouters[sourceChainId] == sourceRouter, "FR: Router not trusted");

        pool.finalizeCross(token, recipient, amount);
    }

    function _bridgeWithPortal(
        uint256 dstChainId,
        address recipient,
        address sourceFoundryToken,
        uint256 amount,
        uint256 feeAmount
    ) internal {
        _moveTokens(portal.feeToken(), msg.sender, portal.feeTarget(), feeAmount); // FRM

        address remoteFoundryToken = _getAndCheckRemoteFoundryToken(sourceFoundryToken, uint64(dstChainId));

        bytes memory remoteCalldata = abi.encodeWithSelector(this.finalizeCross.selector, remoteFoundryToken, recipient, amount);
        portal.run(
            uint64(dstChainId), // dstChainId 
            trustedRemoteRouters[dstChainId], // targetContractOnDstChain
            recipient, // any refunds
            remoteCalldata // the calldata to be executed on the target contract
        );
    }

    function _transferToPool(
        address token,
        address from,
        uint256 amount
    ) internal returns (uint256) {
        _moveTokens(token, from, address(pool), amount);
        amount = pool.initiateCross(token);
        return amount;
    }
}
