import { ethers } from "hardhat";
import { expect } from "chai";
import { QuantumPortalUtils, deployAll } from "../quantumPortal/QuantumPortalUtils";
import { FiberRouterV2, Pool, PingPong } from "../../typechain-types";
import hre from "hardhat";


describe('FiberRouter', function() {

    let fiberRouter1,
        fiberRouter2,
        pool1,
        pool2,
        ctx,
        swapRouter,
        usdc1,
        usdc2,
        signer,
        recipient

	beforeEach('Setup', async function() {
        ctx = await deployAll();
        [signer, recipient] = await hre.ethers.getSigners()

        swapRouter = await hre.ethers.deployContract("SwapRouter")
        usdc1 = await hre.ethers.deployContract("Token")
        usdc2 = await hre.ethers.deployContract("Token")

        const poolF = await ethers.getContractFactory('Pool');
        const fiberRouterF = await ethers.getContractFactory('FiberRouterV2');

        pool1 = await poolF.deploy(
            signer.address,
            signer.address,
            signer.address,
            signer.address,
            signer.address,
        ) as Pool
        pool2 = await poolF.deploy(
            signer.address,
            signer.address,
            signer.address,
            signer.address,
            signer.address,
        ) as Pool

        fiberRouter1 = await fiberRouterF.deploy(
            pool1.address,
            signer.address,
            ctx.chain1.poc.address,
            signer.address,
            signer.address
        ) as FiberRouterV2

        fiberRouter2 = await fiberRouterF.deploy(
            pool2.address,
            signer.address,
            ctx.chain2.poc.address,
            signer.address,
            signer.address
        ) as FiberRouterV2

        await pool1.setFiberRouter(fiberRouter1.address)
        await pool2.setFiberRouter(fiberRouter2.address)
        await fiberRouter1.addTokenPaths([usdc1.address], [ctx.chain2.chainId], [usdc2.address])
        await fiberRouter2.addTokenPaths([usdc2.address], [ctx.chain1.chainId], [usdc1.address])
        await fiberRouter1.addTrustedRemotes([ctx.chain2.chainId], [fiberRouter2.address])
        await fiberRouter2.addTrustedRemotes([ctx.chain1.chainId], [fiberRouter1.address])

        const million = 1000000n
        await usdc1.mint(swapRouter.address, million)
        await usdc1.mint(signer.address, million * 2n)
        await usdc2.mint(signer.address, million * 2n)

        await usdc1.approve(pool1.address, million)
        await pool1.addLiquidity(usdc1.address, million)
        await usdc2.approve(pool2.address, million)
        await pool2.addLiquidity(usdc2.address, million)

        await ctx.chain1.token.transfer(signer.address, ethers.utils.parseEther('10'));
        await ctx.chain2.token.transfer(signer.address, ethers.utils.parseEther('10'));
    })

    it("should transfer tokens from one chain to another", async function() {
        await ctx.chain1.token.approve(fiberRouter1.address, ethers.utils.parseEther('1'));
        const amount = 100
        const feeAmount = ethers.utils.parseEther('1')
        await usdc1.approve(fiberRouter1.address, amount)

        console.log("fiberRouter2.address", fiberRouter2.address)
        const preBal = await usdc2.balanceOf(recipient.address)
        
        await fiberRouter1.cross(
            usdc1.address,
            amount,
            feeAmount,
            recipient.address,
            ctx.chain2.chainId,
            0
        )

        await QuantumPortalUtils.mineAndFinilizeOneToTwo(ctx, 1);

        const postBal = await usdc2.balanceOf(recipient.address)
        console.log(preBal)
        console.log(postBal)
        expect(postBal).to.equal(preBal.add(amount))
    })
})