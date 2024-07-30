import { FiberRouterV2 } from "../../../typechain-types";
import { ethers } from "hardhat";
import hre from "hardhat";

// Function to get environment variables
function getEnvVariable(name: string): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing environment variable ${name}`);
    }
    return value;
}

async function main() {
    const otherFiberRouterAddress = getEnvVariable("OTHER_FIBER_ROUTER_ADDRESS");
    const fiberRouterAddress = getEnvVariable("FIBER_ROUTER_ADDRESS");
    const thisUsdc = getEnvVariable("THIS_USDC");
    const otherUsdc = getEnvVariable("OTHER_USDC");
    const otherChainId = parseInt(getEnvVariable("OTHER_CHAIN_ID"), 10);

    const fiberRouterF = await ethers.getContractFactory('FiberRouterV2');
    const fiberRouter = fiberRouterF.attach(fiberRouterAddress) as FiberRouterV2;

    await fiberRouter.addTrustedRemotes([otherChainId], [otherFiberRouterAddress]);
    await fiberRouter.addTokenPaths([thisUsdc], [otherChainId], [otherUsdc]);

    console.log(`\n###############\nNetwork: ${hre.network.name}`);
    console.log("Post deploy setup complete");
}

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
});
