import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber, Contract } from "ethers";


describe("LiquidityPool", function() {
  var liquidityPool: Contract;
  var tokenA: Contract;
  var tokenB: Contract;
  var owner: any;

  async function deployTokens(amountA: number, amountB: number) {
    const TokenA = await ethers.getContractFactory("TokenA");
    const TokenB = await ethers.getContractFactory("TokenB");

    tokenA = await TokenA.deploy(amountA);
    tokenB = await TokenB.deploy(amountB);

    await tokenA.deployed();
    await tokenB.deployed();

    return { amountA: amountA, amountB: amountB };
  }

  async function deployContract(tokenAddressA: string, tokenAddressB: string) {
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    liquidityPool = await LiquidityPool.deploy(tokenAddressA, tokenAddressB);

    await liquidityPool.deployed();
  }

  it("Should add first liquidity", async function() {
    [owner] = await ethers.getSigners();

    const balanceA = 10 * 10**8;
    const balanceB = 5 * 10**8;

    const { amountA, amountB } = await deployTokens(balanceA, balanceB);
    await deployContract(tokenA.address, tokenB.address);

    await tokenA.approve(liquidityPool.address, balanceA);
    await tokenB.approve(liquidityPool.address, balanceB);

    await liquidityPool.depositLiquidity(balanceA, balanceB);

    expect(await tokenA.balanceOf(liquidityPool.address)).to.equal(balanceA);
    expect(await tokenB.balanceOf(liquidityPool.address)).to.equal(balanceB);
  });

  it("Should mint and distribute liquidity tokens", async function() {
    const totalSupply = await liquidityPool.totalSupply();

    expect(totalSupply).to.be.greaterThan(0, "No tokens minted");
    expect(totalSupply.sub(await liquidityPool.balanceOf(owner.address))).to.be.equal(1000);
  });

  it("Should swap tokenA for tokenB", async function() {

  });

  it("Should remove liquidity and burn tokens", async function() {
    const balanceA = await tokenA.balanceOf(liquidityPool.address) as BigNumber;
    const balanceB = await tokenB.balanceOf(liquidityPool.address) as BigNumber;
    const liquidityTokens = await liquidityPool.balanceOf(owner.address) as BigNumber;

    await liquidityPool.approve(liquidityPool.address, liquidityTokens);
    await liquidityPool.withdrawLiquidity(liquidityTokens);

    const expectedBalanceA = calculateLiquidityShareBalance(balanceA, liquidityTokens, liquidityTokens.add(1000));
    const expectedBalanceB = calculateLiquidityShareBalance(balanceB, liquidityTokens, liquidityTokens.add(1000));

    expect(await tokenA.balanceOf(owner.address)).to.be.eq(expectedBalanceA);
    expect(await tokenB.balanceOf(owner.address)).to.be.eq(expectedBalanceB);

    expect(await liquidityPool.balanceOf(owner.address)).to.be.eq(0);
  });


})

function calculateLiquidityShareBalance(balance: BigNumber, supplyOwned: BigNumber, totalSupply: BigNumber) {
  return Math.trunc(balance.toNumber() * supplyOwned.toNumber() / totalSupply.toNumber())
}
