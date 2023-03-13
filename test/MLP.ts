import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat"
import { BigNumber, Contract } from "ethers";
import { formatUnits, parseEther, parseUnits } from "@ethersproject/units";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import deploy_tests from "../scripts/deploy_tests";
const IERC20 = require("../ERC20Abi.json")
var assert = require('chai').assert
import RewardRouterAbi from "../RewardRouterAbi.json";
// const usdc_polygon_address = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"

const gnosis = "0x25b3d91e2cbAe2397749f2F9A5598366Df26fA49";
let owner: SignerWithAddress, otherAccounts: SignerWithAddress[];
let fsMLPWhale2:any = "0xce52c2e8e54cc717d1b35ac730406141ddccb47d";
let fsMLPWhale1:any = "0x08048f6d9db401d2716dcbb1979513231e5e3c81";
let fsMLPWhale3:any = "0xaa042a7010fc42bed6d33bd4702e8ec28af8ba48";
let polygonWhale:any = "0xd5c08681719445a5fdce2bda98b341a49050d821"

let handler: any;
let mlpVault: any;
let mlp_adapter: any;
let deepfiToken: any;
let testToken6: any;
let testToken18: any;
let mLP: any;
let mMY: any;
let esMMY:any;
let fsMLP: any;
let stakedGLP: any;
let managerGLP: any;
let rewardRouter:any;

let testMummy:any;

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
    await mlpVault.connect(owner).setRewardsDuration(duration);
  }

  if (amount != undefined) {
    await mlpVault.connect(owner).notifyRewardAmount(amount);
  }
}

async function deposit(recipient: SignerWithAddress, token: Contract, amount: BigNumber) {
  // console.log('!enter deposit ')
  // if (recipient != owner)
  // {
    await token.connect(owner).transfer(recipient.address, amount);
    // console.log('!enter deposit1 ')
  // }
  
  await token.connect(recipient).approve(mlpVault.address, amount);
  // console.log('!enter deposit2.4 ')

  await mlpVault.connect(recipient).deposit(amount);
  // console.log('!enter deposit ENDED')

}

function getRandomNumber(min: number, max: number) {
  return Math.floor(Math.random() * (max - min) + min);
}

describe("🌞 Deployment of Deposit.Finance Protocol", async () => {
  before(async () => {
    //   //We are forking Polygon mainnet, please set Alchemy key in .env
    //   await network.provider.request({
    //     method: "hardhat_reset",
    //     params: [{
    //         forking: {
    //             enabled: true,
    //             jsonRpcUrl: process.env.FORKING_URL as string,
    //             //you can fork from last block by commenting next line
    //             blockNumber: 57393222,
    //         },
    //     },],
    // });

    otherAccounts = await ethers.getSigners();
    owner = await getImpersonatedSigner(fsMLPWhale1);
    // console.log("admin address is", owner.address);

    // MLP 
    mLP = await ethers.getContractAt(IERC20, '0x0ce61aaf89500e4f007884fbbf62642618def5dd')
    mMY = await ethers.getContractAt(IERC20, "0x01e77288b38b416F972428d562454fb329350bAc"); 

    esMMY = await ethers.getContractAt(IERC20, "0xe41c6c006De9147FC4c84b20cDFBFC679667343F"); 

    //reward tracker
    fsMLP = await ethers.getContractAt(IERC20, '0xFfB69477FeE0DAEB64E7dE89B57846aFa990e99C')
    stakedGLP = await ethers.getContractAt(IERC20, '0xfdc9b5be032216315bbe8c06b1c4f563d1689b85') 
    managerGLP = await ethers.getContractAt(IERC20, '0x304951d7172bCAdA54ccAC1E4674862b3d5b3d5b') 
    rewardRouter = await ethers.getContractAt(RewardRouterAbi, '0x7b9e962dd8AeD0Db9A1D8a2D7A962ad8b871Ce4F') 
    
  });

  beforeEach(async () => {
    ({ testToken6, 
      testToken18, 
      deepfiToken, 
      handler, 
      mlpVault, 
      mlp_adapter
    } = await deploy_tests(owner, stakedGLP));  

  
    let TestM = await ethers.getContractFactory("TestM");
    testMummy = await TestM.deploy();
    await testMummy.deployed();

    await stakedGLP.connect(owner).transfer(testMummy.address, parseUnits("1000", 18));
  })

    describe("🌱 Check Vault Functionality", async () => {

    //   it("Test 1 : basic compound", async () => {
    //     await rewardRouter.connect(owner).handleRewards(true, false, true, false, false, true, true);

    //   console.log("Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(owner.address), 18))
    //   console.log("Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(owner.address), 18))
    //   console.log("Balance of MLP => ", formatUnits(await mLP.balanceOf(owner.address), 18))
    //   console.log("Balance of MMY => ", formatUnits(await mMY.balanceOf(owner.address), 18))
    //   console.log("Balance of esMMY => ", formatUnits(await esMMY.balanceOf(owner.address), 18))
    //   console.log("Balance of ETH => ", formatUnits(await owner.getBalance(), 18))
    //         await skipDays(15);

    //         console.log("------------------------------------");
    //         await rewardRouter.connect(owner).handleRewards(true, true, true, true, true, true, true);
    //   console.log("Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(owner.address), 18))
    //   console.log("Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(owner.address), 18))
    //   console.log("Balance of MLP => ", formatUnits(await mLP.balanceOf(owner.address), 18))
    //   console.log("Balance of MMY => ", formatUnits(await mMY.balanceOf(owner.address), 18))
    //   console.log("Balance of esMMY => ", formatUnits(await esMMY.balanceOf(owner.address), 18))
    //   console.log("Balance of ETH => ", formatUnits(await owner.getBalance(), 18))
    //   console.log("------------------------------------");
    //   // await skipDays(15);
    //   // await rewardRouter.connect(owner).handleRewards(true, true, true, true, true, true, true);

    //   await rewardRouter.connect(owner).handleRewards(true, false, true, false, false, true, true);
    //   console.log("Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(owner.address), 18))
    //   console.log("Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(owner.address), 18))
    //   console.log("Balance of MLP => ", formatUnits(await mLP.balanceOf(owner.address), 18))
    //   console.log("Balance of MMY => ", formatUnits(await mMY.balanceOf(owner.address), 18))
    //   console.log("Balance of esMMY => ", formatUnits(await esMMY.balanceOf(owner.address), 18))
    //   console.log("Balance of ETH => ", formatUnits(await owner.getBalance(), 18))

    //   console.log("------------------------------------");
    //         await skipDays(15);
    //   await rewardRouter.connect(owner).handleRewards(true, true, true, true, true, true, true);

    //   await rewardRouter.connect(owner).handleRewards(true, false, true, false, false, true, true);
    //   console.log("Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(owner.address), 18))
    //   console.log("Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(owner.address), 18))
    //   console.log("Balance of MLP => ", formatUnits(await mLP.balanceOf(owner.address), 18))
    //   console.log("Balance of MMY => ", formatUnits(await mMY.balanceOf(owner.address), 18))
    //   console.log("Balance of esMMY => ", formatUnits(await esMMY.balanceOf(owner.address), 18))
    //   console.log("Balance of ETH => ", formatUnits(await owner.getBalance(), 18))
    // });



      it("Test 2 : 1 user staking 100% tvl on 1000 reward / 10 days", async () => {
      // console.log("reward router Res => ", await rewardRouter.handleRewards(true, true, true, true, true, true, true));
        // console.log("Adapter Res => ", await mlp_adapter.connect(owner).getAdapterAmount());
        await setReward(864000, parseEther("1000"));
        console.log("------------------------------------");
        console.log("Before Deposit Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(mlp_adapter.address), 18))
        console.log("Before Deposit Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(mlp_adapter.address), 18))
        console.log("Before Deposit Balance of MLP => ", formatUnits(await mLP.balanceOf(mlp_adapter.address), 18))
        console.log("Before Deposit Balance of MMY => ", formatUnits(await mMY.balanceOf(mlp_adapter.address), 18))
        console.log("Before Deposit Balance of esMMY => ", formatUnits(await esMMY.balanceOf(mlp_adapter.address), 18))
        console.log("Before Deposit Balance of ETH => ", formatUnits(await ethers.provider.getBalance(mlp_adapter.address), 18));
        console.log("------------------------------------");
        await deposit(otherAccounts[0], stakedGLP, ethers.utils.parseUnits("10000", 18));
        console.log("------------------------------------");
        console.log("After Deposit Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(mlp_adapter.address), 18))
        console.log("After Deposit Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(mlp_adapter.address), 18))
        console.log("After Deposit Balance of MLP => ", formatUnits(await mLP.balanceOf(mlp_adapter.address), 18))
        console.log("After Deposit Balance of MMY => ", formatUnits(await mMY.balanceOf(mlp_adapter.address), 18))
        console.log("After Deposit Balance of esMMY => ", formatUnits(await esMMY.balanceOf(mlp_adapter.address), 18))
        console.log("Before Deposit Balance of ETH => ", formatUnits(await ethers.provider.getBalance(mlp_adapter.address), 18));
        console.log("------------------------------------");

      await skipDays(60);
      console.log("------------------------------------");
      console.log("After 30 days Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(mlp_adapter.address), 18))
      console.log("After 30 days Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(mlp_adapter.address), 18))
      console.log("After 30 days Balance of MLP => ", formatUnits(await mLP.balanceOf(mlp_adapter.address), 18))
      console.log("After 30 days Balance of MMY => ", formatUnits(await mMY.balanceOf(mlp_adapter.address), 18))
      console.log("After 30 days Balance of esMMY => ", formatUnits(await esMMY.balanceOf(mlp_adapter.address), 18))
      console.log("Before Deposit Balance of ETH => ", formatUnits(await ethers.provider.getBalance(mlp_adapter.address), 18));
      console.log("------------------------------------");

      // console.log("Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(owner.address), 18))
      // console.log("Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(owner.address), 18))
      // console.log("Balance of MLP => ", formatUnits(await mLP.balanceOf(owner.address), 18))
      // await mlp_adapter.claimAdapterReward();
      await mlpVault.connect(otherAccounts[0]).withdraw(parseUnits("10000", 18));
      await mlpVault.connect(otherAccounts[0]).claimReward();
      console.log("------------------------------------");
      console.log("Balance of StakedMLP => ", formatUnits(await stakedGLP.balanceOf(mlp_adapter.address), 18))
      console.log("Balance of fsMLP => ", formatUnits(await fsMLP.balanceOf(mlp_adapter.address), 18))
      console.log("Balance of MLP => ", formatUnits(await mLP.balanceOf(mlp_adapter.address), 18))
      console.log("Balance of MMY => ", formatUnits(await mMY.balanceOf(mlp_adapter.address), 18))
      console.log("Balance of esMMY => ", formatUnits(await esMMY.balanceOf(mlp_adapter.address), 18))
      console.log("Before Deposit Balance of ETH => ", formatUnits(await ethers.provider.getBalance(mlp_adapter.address), 18));
      console.log("Before Deposit Balance of ETH => ", await mlp_adapter.balance());
      console.log("------------------------------------");

      console.log("Ended <3")
      // console.log("Adapter Res => ", await mlp_adapter.connect(owner).getAdapterAmount());
      // expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[0].address), 18))).is.above(999)
    });



    // it("Test 2 : 4 users staking 10/10/30/50% on 1000 reward", async () => {
    //   await setReward(864000, parseEther("1000"));

    //   await deposit(otherAccounts[0], stakedGLP, ethers.utils.parseUnits("100", 18));
    //   await deposit(otherAccounts[1], stakedGLP, ethers.utils.parseUnits("100", 18));
    //   await deposit(otherAccounts[2], stakedGLP, ethers.utils.parseUnits("300", 18));
    //   await deposit(otherAccounts[3], stakedGLP, ethers.utils.parseUnits("500", 18));

    //   await skipDays(15);
    //   await mlpVault.connect(otherAccounts[0]).claimReward();
    //   await mlpVault.connect(otherAccounts[1]).claimReward();
    //   await mlpVault.connect(otherAccounts[2]).claimReward();
    //   await mlpVault.connect(otherAccounts[3]).claimReward();

    //   await mlpVault.connect(otherAccounts[0]).withdraw(parseUnits("100", 18));
    //   await mlpVault.connect(otherAccounts[1]).withdraw(parseUnits("100", 18));
    //   await mlpVault.connect(otherAccounts[2]).withdraw(parseUnits("300", 18));
    //   await mlpVault.connect(otherAccounts[3]).withdraw(parseUnits("500", 18));

    //   expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[0].address), 18))).is.above(99)
    //   expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[1].address), 18))).is.above(99)
    //   expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[2].address), 18))).is.above(299)
    //   expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[3].address), 18))).is.above(499)
    // });

  });

});

