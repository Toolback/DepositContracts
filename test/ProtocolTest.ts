import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat"
import { Contract } from "ethers";
import { parseEther, parseUnits } from "@ethersproject/units";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const IERC20 = require ("../ERC20Abi.json")
var assert = require('chai').assert

const usdc_polygon_address = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"

const gnosis = "0x25b3d91e2cbAe2397749f2F9A5598366Df26fA49";
let owner:SignerWithAddress , otherAccount:SignerWithAddress;

let handler: Contract;
let pool_usdc: Contract;
let defiToken: Contract;
let usdcPolygon: any;

async function getImpersonatedSigner(address: string): Promise<SignerWithAddress> {
  await ethers.provider.send(
    'hardhat_impersonateAccount',
    [address]
  );

  return await ethers.getSigner(address);
}


async function skipDays(d: number) {
  ethers.provider.send('evm_increaseTime', [d * 86400]);
  ethers.provider.send('evm_mine', []);
}

describe("Deployment of Defi.Finance Protocol", async () => {
  before(async () => {
    //   //We are forking Polygon mainnet, please set Alchemy key in .env
    //   await network.provider.request({
    //     method: "hardhat_reset",
    //     params: [{
    //         forking: {
    //             enabled: true,
    //             jsonRpcUrl: process.env.FORKING_URL as string,
    //             //you can fork from last block by commenting next line
    //             blockNumber: 28955535,
    //         },
    //     },],
    // });

    [otherAccount,] = await ethers.getSigners();
    owner = await getImpersonatedSigner("0xd5c08681719445a5fdce2bda98b341a49050d821");
    // console.log("admin address is", owner.address);

    usdcPolygon = await ethers.getContractAt(IERC20, usdc_polygon_address);
    // Defi Token
    const DefiToken = await ethers.getContractFactory("DefiToken");

    defiToken = await upgrades.deployProxy(DefiToken,
      [owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );
    // console.log("defiToken upgradable deployed to:", defiToken.address);


    // Liquidity Handler
    const Handler = await ethers.getContractFactory("LiquidityHandler");

    handler = await upgrades.deployProxy(Handler,
      [owner.address, defiToken.address],
      { initializer: 'initialize', kind: 'uups' }
    );

    // console.log("Handler upgradable deployed to:", handler.address);

    const UsdcPool = await ethers.getContractFactory("D_Pool_SingleReward");

    pool_usdc = await upgrades.deployProxy(UsdcPool,
      [usdc_polygon_address, defiToken.address, owner.address, handler.address, owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );

    // console.log("Handler upgradable deployed to:", handler.address);

    handler.connect(owner).addPool(pool_usdc.address);
    handler.connect(owner).grantRole(handler.DEFAULT_ADMIN_ROLE(), pool_usdc.address);
    expect((await handler.getDeployedPools())[0]).to.be.equal(pool_usdc.address)

  });


  describe("--> Test Started", async () => {
  it("Admin should deposit Defi Token to UsdcPool for claimable staking reward", async () => {
    await defiToken.connect(owner).transfer(pool_usdc.address, parseEther("1000000"))
    expect(ethers.utils.formatUnits((await defiToken.balanceOf(pool_usdc.address)).toString(), 18)).to.be.equal("1000000.0");
  });
  
  it("Admin should set reward duration", async () => {
    // 10 days of distribution
    await pool_usdc.connect(owner).setRewardsDuration(864000)
    // expect(ethers.utils.formatUnits((await pool_usdc.balanceOf(handler.address)).toString(), 18)).to.be.equal("1000000.0");
  });
    it("Admin should set reward quantity", async () => {
      // 1.000.000 on 10 days
      await pool_usdc.connect(owner).notifyRewardAmount(parseEther("1000000"))
      // expect(ethers.utils.formatUnits((await pool_usdc.balanceOf(handler.address)).toString(), 18)).to.be.equal("1000000.0");
    });


  it("User should be able to deposit asset", async () => {
    await usdcPolygon.connect(owner).approve(pool_usdc.address, (100 * 10 ** 6))
    await pool_usdc.connect(owner).deposit(100 * 10 ** 6);
    // expect((await usdcPolygon.balanceOf(owner.address)).toString()).to.be.equal(ethers.utils.parseUnits("100", 6))
  });

  it("Should check user claimable reward", async () => {
        // Conversion de l'APR en taux d'intérêt journalier


    console.log("reward after 0days => ", await pool_usdc.getRewardBalance(owner.address));

  // advance time by one hour and mine a new block
    // await time.increase(3000000);
    await skipDays(30);

    console.log("reward after 30days => ", await pool_usdc.getRewardBalance(owner.address));

    await skipDays(30);
    console.log("reward after 60days => ", ethers.utils.formatUnits(await pool_usdc.getRewardBalance(owner.address), 6));

    // let maxClaim = await pool_usdc.getRewardBalance(owner.address);
    await pool_usdc.connect(owner).claimReward();
    
    console.log("returned claim bal => ", await defiToken.balanceOf(owner.address));
    
    await pool_usdc.connect(owner).withdraw(100 * 10 ** 6);
    console.log("final claimed bal => ", ethers.utils.formatUnits(await defiToken.balanceOf(owner.address), 18));

    // expect(ethers.utils.formatUnits((await DToken.balanceOf(handler.address)).toString(), 18)).to.be.equal("1000000.0");
  });
  
  })
  
});





