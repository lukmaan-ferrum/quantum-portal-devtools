import { ethers } from "hardhat";
import { QuantumPortalLedgerMgrTest } from "../../typechain-types/QuantumPortalLedgerMgrTest";
import { QuantumPortalPocTest } from "../../typechain-types/QuantumPortalPocTest";
import { DeployQp } from '../../typechain-types/DeployQp';
import { QuantumPortalGatewayDEV } from "../../typechain-types/QuantumPortalGatewayDEV";
import { QpFeeToken } from '../../typechain-types/QpFeeToken';
import hre from "hardhat";

interface PortalContext {
    chain1: {
        chainId: number;
        ledgerMgr: QuantumPortalLedgerMgrTest;
        poc: QuantumPortalPocTest;
        token: QpFeeToken;
    }
}

async function main() {
    const depF = await ethers.getContractFactory('DeployQp');
    const dep1 = await depF.deploy() as DeployQp;

    const gateF = await ethers.getContractFactory('QuantumPortalGatewayDEV');

    const chainId1 = (await dep1.realChainId()).toNumber();
    console.log(`\n###############\nNetwork: ${hre.network.name}`);

    const mgrF = await ethers.getContractFactory('QuantumPortalLedgerMgrTest');
    const mgr1 = await mgrF.deploy(chainId1) as QuantumPortalLedgerMgrTest;
    await mgr1.transferOwnership(dep1.address);
    const pocF = await ethers.getContractFactory('QuantumPortalPocTest');
    const poc1 = await pocF.deploy(chainId1) as QuantumPortalPocTest;
    await poc1.transferOwnership(dep1.address);

    await dep1.deployWithToken(chainId1, mgr1.address, poc1.address);
    const gate1 = gateF.attach(await dep1.gateway()) as QuantumPortalGatewayDEV;

    const tokF = await ethers.getContractFactory('QpFeeToken');
    console.log('Deployment complete')
    console.log(`Chain ID: ${chainId1}`);
    console.log("Gate:   \t", gate1.address);
    console.log("Ledger: \t", mgr1.address);
    console.log("Portal: \t", poc1.address);
    console.log("FeeConverter: \t", await dep1.feeConverter());
    console.log("FeeToken:  \t", await gate1.feeToken());

    const context: PortalContext = {
        chain1: {
            chainId: chainId1,
            ledgerMgr: mgrF.attach(await gate1.quantumPortalLedgerMgr()),
            poc: pocF.attach(await gate1.quantumPortalPoc()),
            token:  tokF.attach(await gate1.feeToken()),
        }
    };

    return context;
}

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
});
