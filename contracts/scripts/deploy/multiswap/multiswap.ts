import { FiberRouterV2, Pool } from "../../../typechain-types";
import { ethers } from "hardhat";
import hre from "hardhat";
import { BigNumber } from "ethers";

// Function to get environment variables
function getEnvVariable(name: string): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing environment variable ${name}`);
    }
    return value;
}

async function main() {
    const portalAddress = getEnvVariable("PORTAL_ADDRESS");

    const signers = await hre.ethers.getSigners();
    const signer = signers[0];

    const million = 1000000n;
    console.log(hre.network.name);

    let usdc;
    if (hre.network.name.includes("localhost")) {
        usdc = await hre.ethers.deployContract("Token");
        await usdc.mint(signer.address, million * 200n);
    } else if (hre.network.name.includes("base")) {
        const usdcF = await ethers.getContractFactory('Token');
        usdc = usdcF.attach("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913");
    } else if (hre.network.name.includes("arbitrumOne")) {
        const usdcF = await ethers.getContractFactory('Token');
        usdc = usdcF.attach("0xaf88d065e77c8cC2239327C5EDb3A432268e5831");
    }

    const poolF = await ethers.getContractFactory('Pool');
    const fiberRouterF = await ethers.getContractFactory('FiberRouterV2');

    const pool = await poolF.deploy(
        signer.address,
        signer.address,
        signer.address,
        signer.address,
        signer.address // Skipping ccipRouter for now
    ) as Pool;

    const fiberRouter = await fiberRouterF.deploy(
        pool.address,
        signer.address,
        portalAddress,
        signer.address,
        signer.address
    ) as FiberRouterV2;

    await pool.setFiberRouter(fiberRouter.address);
    await usdc.approve(pool.address, million);
    await pool.addLiquidity(usdc.address, million);

    console.log(`\n###############\nNetwork: ${hre.network.name}`);
    console.log("FiberRouter: \t", fiberRouter.address);
    console.log("Pool: \t\t", pool.address);
    console.log("USDC: \t\t", usdc.address);
}

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
});
