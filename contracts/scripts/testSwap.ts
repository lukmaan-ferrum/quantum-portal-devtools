import { FiberRouterV2, Pool, PingPong } from "../typechain-types";
import { ethers } from "hardhat";
import hre from "hardhat";


async function main() {
    const signers = await hre.ethers.getSigners()
    const signer = signers[0]
    const recipient = "0x4511239C5dF97F8c266Def3118520Adb87e2bF84"
    const usdcF = await ethers.getContractFactory('Token');

    //////////////////////////////
    const feeTokenAddress = "0x1549cAa526A039681C76745Ff61a245D29706CC9"
    const fiberRouterAddress = "0x783eaa3d0faC7e1e335705A0554cD98E15e72dFD"
    const usdc = usdcF.attach("0xf9B3C3306C46eC821B41E5b4ada4FEC452c92b44")
    //////////////////////////////

    const tokF = await ethers.getContractFactory('QpFeeToken');
    const feeToken = tokF.attach(feeTokenAddress)

    const fiberRouterF = await ethers.getContractFactory('FiberRouterV2');
    const fiberRouter = fiberRouterF.attach(fiberRouterAddress) as FiberRouterV2
    await usdc.approve(fiberRouter.address, ethers.utils.parseEther("10"));
    await feeToken.approve(fiberRouter.address, ethers.utils.parseEther("10"));

    console.log("\nUSDC Balance before")
    console.log("Sender:\t\t" + ethers.utils.formatUnits(await usdc.balanceOf(signer.address), 6))

    await fiberRouter.cross(
        usdc.address,
        ethers.utils.parseUnits("1", 6),
        ethers.utils.parseEther("1"),
        recipient,
        31337,
        0
    )

    console.log("\nUSDC Balance after")
    console.log("Sender:\t\t" + ethers.utils.formatUnits(await usdc.balanceOf(signer.address), 6))
}

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
});
