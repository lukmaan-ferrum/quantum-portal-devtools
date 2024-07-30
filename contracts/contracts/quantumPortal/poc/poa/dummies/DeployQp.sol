// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./QpDependenciesDev.sol";
import "../QuantumPortalFeeConvertorDirect.sol";
import "../../test/QuantumPortalPocTest.sol";
import "../../QuantumPortalLedgerMgr.sol";
import "../../QuantumPortalNativeFeeRepo.sol";
import "../../QuantumPortalState.sol";
import "../../QuantumPortalGateway.sol";

contract QpFeeToken is ERC20Burnable {
        constructor() ERC20("QP Fee Test Token", "TQP") {
                _mint(msg.sender, 1000000000 * 10 ** 18);
        }
}

interface IUpdater {
    function updateState(address addr) external;
    function updateLedger(address addr) external;
    function updateAuthorityMgr(address addr) external;
    function updateMinerMgr(address addr) external;
    function updateFeeConvertor(address addr) external;
    function updateFeeTarget() external;
    function setFeeToken(address addr) external;
    function setNativeFeeRepo(address addr) external;
    function transferOwnership(address addr) external;
    function setManager(address _mgr, address _state) external;
}

contract DeployQp {
    address public gateway;
    address public feeToken;
    address public feeConverter;

    function deployFeeToken() public {
        address _feeToken = address(new QpFeeToken{salt: bytes32(0x0)}());
        feeToken = _feeToken;
        IERC20(feeToken).transfer(msg.sender, IERC20(feeToken).balanceOf(address(this)));
    }

    function deployWithToken(uint64 overrideChainId, address mgr, address ledger) external {
        deployFeeToken();
        deploy(feeToken, overrideChainId, mgr, ledger);
    }

    function deploy(address _feeToken, uint64 overrideChainId, address mgr, address ledger) public {
        if (overrideChainId == 0) {
            overrideChainId = uint64(block.chainid);
        }
        feeToken = _feeToken;
        QuantumPortalNativeFeeRepo nativeFee = new QuantumPortalNativeFeeRepo{salt: bytes32(0x0)}();
        QuantumPortalFeeConvertorDirect _feeConvertor = new QuantumPortalFeeConvertorDirect{salt: bytes32(0x0)}();
        feeConverter = address(_feeConvertor);
        QuantumPortalState state = new QuantumPortalState{salt: bytes32(0x0)}();
        QuantumPortalGatewayDEV _gateway = new QuantumPortalGatewayDEV{salt: bytes32(0x0)}();
        gateway = address(_gateway);

        QpDependenciesDev deps = new QpDependenciesDev{salt: bytes32(0x0)}(_feeToken);

        nativeFee.init(address(ledger), address(_feeConvertor));
        state.setMgr(address(mgr));
        state.setLedger(address(ledger));

        IUpdater(address(mgr)).updateState(address(state));
        IUpdater(address(mgr)).updateLedger(address(ledger));
        IUpdater(address(mgr)).updateAuthorityMgr(address(deps));
        IUpdater(address(mgr)).updateMinerMgr(address(deps));
        IUpdater(address(mgr)).updateFeeConvertor(address(_feeConvertor));

        IUpdater(address(ledger)).setManager(mgr, address(state));
        IUpdater(address(ledger)).setFeeToken(_feeToken);
        IUpdater(address(ledger)).setNativeFeeRepo(address(nativeFee));
        _gateway.upgrade(address(ledger), address(mgr));
        IUpdater(address(ledger)).updateFeeTarget();
        _feeConvertor.updateFeePerByte(1 * 10**15); // 0.001 FRM per byte

        nativeFee.transferOwnership(msg.sender);
        _feeConvertor.transferOwnership(msg.sender);
        state.transferOwnership(msg.sender);
        IUpdater(address(mgr)).transferOwnership(msg.sender);
        IUpdater(address(ledger)).transferOwnership(msg.sender);
        _gateway.transferOwnership(msg.sender);
    }

    function realChainId() external view returns (uint256) {
        return block.chainid;
    }
}
