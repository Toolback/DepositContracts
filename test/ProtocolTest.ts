import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat"
import { BigNumber, Contract } from "ethers";
import { formatUnits, parseEther, parseUnits } from "@ethersproject/units";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const IERC20 = require("../ERC20Abi.json")
var assert = require('chai').assert

const usdc_polygon_address = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"

const gnosis = "0x25b3d91e2cbAe2397749f2F9A5598366Df26fA49";
let owner: SignerWithAddress, otherAccounts: SignerWithAddress[];

let handler: Contract;
let pool_usdc: Contract;
let defiToken: Contract;
let usdcPolygon: any;

let initialBalance: String;
let onGoingBal: String;

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

async function setReward(duration?: number, amount?: BigNumber) {
  if (duration != undefined) {
    await pool_usdc.connect(owner).setRewardsDuration(duration);
  }

  if (amount != undefined) {
    await pool_usdc.connect(owner).notifyRewardAmount(amount);
  }
}

async function deposit(recipient: SignerWithAddress, token: Contract, amount: BigNumber) {
  await token.connect(owner).transfer(recipient.address, amount);

  await token.connect(recipient).approve(pool_usdc.address, amount);

  await pool_usdc.connect(recipient).deposit(amount);
}

function getRandomNumber(min: number, max: number) {
  return Math.floor(Math.random() * (max - min) + min);
}

describe("Deployment of Deposit.Finance Protocol", async () => {
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

    otherAccounts = await ethers.getSigners();
    owner = await getImpersonatedSigner("0xd5c08681719445a5fdce2bda98b341a49050d821");
    // console.log("admin address is", owner.address);

    usdcPolygon = await ethers.getContractAt(IERC20, usdc_polygon_address);
  });

  beforeEach(async () => {
    // Defi Token
    const DefiToken = await ethers.getContractFactory("DefiToken");
    defiToken = await upgrades.deployProxy(DefiToken,
      [owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );

    // Liquidity Handler
    const Handler = await ethers.getContractFactory("LiquidityHandler");
    handler = await upgrades.deployProxy(Handler,
      [owner.address, defiToken.address],
      { initializer: 'initialize', kind: 'uups' }
    );

    // Usdc Pool
    const UsdcPool = await ethers.getContractFactory("D_Pool_SingleReward");
    pool_usdc = await upgrades.deployProxy(UsdcPool,
      [usdc_polygon_address, defiToken.address, owner.address, handler.address, owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );


    handler.connect(owner).addPool(pool_usdc.address);
    handler.connect(owner).grantRole(handler.DEFAULT_ADMIN_ROLE(), pool_usdc.address);
    expect((await handler.getDeployedPools())[0]).to.be.equal(pool_usdc.address)
    await defiToken.connect(owner).transfer(pool_usdc.address, parseEther("1000000"))
    expect(ethers.utils.formatUnits((await defiToken.balanceOf(pool_usdc.address)).toString(), 18)).to.be.equal("1000000.0");
  })

  describe("☄ Check Upgradeablility of Contracts ", async () => {
    // it("Test 1 : Upgrade Defi Token Contract", async () => {
    // });
    // it("Test 2 : Upgrade Liquidity Handler Contract", async () => {
    // });
    it("Test : Upgrade Pool Contract", async () => {
      let currentUsdcPool = await ethers.getContractAt("D_Pool_SingleReward", pool_usdc.address);
      await currentUsdcPool.connect(owner).grantRole("0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3", "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      await currentUsdcPool.connect(owner).changeUpgradeStatus(true);
      await deposit(owner, usdcPolygon, ethers.utils.parseUnits("100", 6));
      const balBefore = formatUnits((await pool_usdc.getStakeBalance(owner.address)).toString(), 6);
      const NewUsdcPool = await ethers.getContractFactory("test_update_pool");
      // let UsdcPool = await upgrades.forceImport(pool_usdc.address, NewUsdcPool);
      const poolv2 = await upgrades.upgradeProxy(pool_usdc, NewUsdcPool);

      console.log("------------------------------------");
      console.log("bal w deposits before upgrade", balBefore);
      console.log("Upgrade complete => ", await poolv2.version());
      console.log("bal after upgrade", formatUnits((await poolv2.getStakeBalance(owner.address)).toString(), 6));
      await poolv2.connect(owner).withdraw(50 * 10 ** 6);
      console.log("bal after upgrade and sub 50", formatUnits((await poolv2.getStakeBalance(owner.address)).toString(), 6));
      console.log("------------------------------------");
    });
  })

  describe("☄ Check Pool Functionality", async () => {
    it("Test 1 : 1 user staking 100% tvl on 1000 reward / 10 days", async () => {
      await setReward(864000, parseEther("1000"));

      initialBalance = ethers.utils.formatUnits(await usdcPolygon.balanceOf(owner.address), 6);
      // await usdcPolygon.connect(owner).approve(pool_usdc.address, (100 * 10 ** 6))
      // await pool_usdc.connect(owner).deposit(100 * 10 ** 6);
      await deposit(owner, usdcPolygon, ethers.utils.parseUnits("100", 6));
      onGoingBal = ethers.utils.formatUnits(await usdcPolygon.balanceOf(owner.address), 6);


      console.log("reward after 0days => ", ethers.utils.formatUnits(await pool_usdc.getRewardBalance(owner.address), 18));
      // advance time by one hour and mine a new block
      // await time.increase(3000000);
      await skipDays(2);

      console.log("reward after 2days => ", ethers.utils.formatUnits(await pool_usdc.getRewardBalance(owner.address), 18));

      await skipDays(2);
      console.log("reward after 4days => ", ethers.utils.formatUnits(await pool_usdc.getRewardBalance(owner.address), 18));
      await skipDays(15);

      // let maxClaim = await pool_usdc.getRewardBalance(owner.address);
      await pool_usdc.connect(owner).claimReward();

      console.log("returned claim bal => ", await defiToken.balanceOf(owner.address));
      console.log("------------------------------------");

      await pool_usdc.connect(owner).withdraw(100 * 10 ** 6);
      console.log("initial USDC bal => ", initialBalance);
      console.log("ongoing USDC Balance (staking)  => ", onGoingBal);
      console.log("final USDC bal => ", ethers.utils.formatUnits(await usdcPolygon.balanceOf(owner.address), 6));

      console.log("final Defi earned bal => ", ethers.utils.formatUnits(await defiToken.balanceOf(owner.address), 18));
      console.log("USDC OWNER BAL => ", ethers.utils.formatUnits(await usdcPolygon.balanceOf(owner.address), 6));

      console.log("------------------------------------");

      // expect(ethers.utils.formatUnits((await DToken.balanceOf(handler.address)).toString(), 18)).to.be.equal("1000000.0");
    });

    it("Test 2 : 4 users staking 10/10/30/50% on 1000 reward", async () => {
      await setReward(864000, parseEther("1000"));

      await deposit(otherAccounts[1], usdcPolygon, parseUnits("100", 6));
      await deposit(otherAccounts[2], usdcPolygon, parseUnits("100", 6));
      await deposit(otherAccounts[3], usdcPolygon, parseUnits("300", 6));
      await deposit(otherAccounts[4], usdcPolygon, parseUnits("500", 6));

      await skipDays(15);

      await pool_usdc.connect(otherAccounts[1]).withdraw(parseUnits("100", 6));
      await pool_usdc.connect(otherAccounts[2]).withdraw(parseUnits("100", 6));
      await pool_usdc.connect(otherAccounts[3]).withdraw(parseUnits("300", 6));
      await pool_usdc.connect(otherAccounts[4]).withdraw(parseUnits("500", 6));

      await pool_usdc.connect(otherAccounts[1]).claimReward();
      await pool_usdc.connect(otherAccounts[2]).claimReward();
      await pool_usdc.connect(otherAccounts[3]).claimReward();
      await pool_usdc.connect(otherAccounts[4]).claimReward();

      console.log("------------------------------------");
      console.log("final Defi earned bal user 1 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[1].address), 18));
      console.log("final Defi earned bal user 2 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[2].address), 18));
      console.log("final Defi earned bal user 3 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[3].address), 18));
      console.log("final Defi earned bal user 4 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[4].address), 18));
      console.log("------------------------------------");
    });


    it("Test 3 : multiple / random users and values on 1000 reward", async () => {
    let numberOfDeposits = getRandomNumber(4, 5);
    let i = 0;

    await setReward(864000, parseEther("1000"));

    while (i <= numberOfDeposits) {
        await deposit(otherAccounts[1], usdcPolygon, parseUnits((getRandomNumber(500, 10000)).toString(), 6));
        await deposit(otherAccounts[2], usdcPolygon, parseUnits((getRandomNumber(500, 10000)).toString(), 6));
        await deposit(otherAccounts[3], usdcPolygon, parseUnits((getRandomNumber(500, 10000)).toString(), 6));
        i++;
    }
    await skipDays(1);
    i = 0;
    let numberOfWithdrawals = getRandomNumber(3, 4);

    while (i <= numberOfWithdrawals / 3) {
        await pool_usdc.connect(otherAccounts[1]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 6));
        await pool_usdc.connect(otherAccounts[2]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 6));
        await pool_usdc.connect(otherAccounts[3]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 6));
        i++;
    }
    await skipDays(3);
    // i = 0;

    while (i <= numberOfWithdrawals) {
        await pool_usdc.connect(otherAccounts[1]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 6));
        await pool_usdc.connect(otherAccounts[2]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 6));
        await pool_usdc.connect(otherAccounts[3]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 6));
        i++;
    }

    await skipDays(10);

    await pool_usdc.connect(otherAccounts[1]).withdraw(await pool_usdc.connect(otherAccounts[1]).getStakeBalance(otherAccounts[1].address));
    await pool_usdc.connect(otherAccounts[2]).withdraw(await pool_usdc.connect(otherAccounts[2]).getStakeBalance(otherAccounts[2].address));
    await pool_usdc.connect(otherAccounts[3]).withdraw(await pool_usdc.connect(otherAccounts[3]).getStakeBalance(otherAccounts[3].address));

    await pool_usdc.connect(otherAccounts[1]).claimReward();
    await pool_usdc.connect(otherAccounts[2]).claimReward();
    await pool_usdc.connect(otherAccounts[3]).claimReward();

    console.log("------------------------------------");
    console.log("final Defi earned bal user 1 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[1].address), 18));
    console.log("final Defi earned bal user 2 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[2].address), 18));
    console.log("final Defi earned bal user 3 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[3].address), 18));
    console.log("------------------------------------");
  })

});

});