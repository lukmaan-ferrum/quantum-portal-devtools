import { ethers } from "hardhat";

async function main() {

    const usdcF = await ethers.getContractFactory('Token');
    const usdc = usdcF.attach("0xf9B3C3306C46eC821B41E5b4ada4FEC452c92b44")

    console.log("USDC Balance: " + ethers.utils.formatUnits(await usdc.balanceOf("0x4511239C5dF97F8c266Def3118520Adb87e2bF84"), 6))
}

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
});
