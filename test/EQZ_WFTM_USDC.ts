import { expect } from "chai";
import { ethers, upgrades } from "hardhat"
import { BigNumber, Contract } from "ethers";
import { formatUnits, parseEther, parseUnits } from "@ethersproject/units";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import deploy_hardhat from "../scripts/deploy_hardhat";
const IERC20 = require("../ABI/ERC20Abi.json")
var assert = require('chai').assert
import eqz_router_abi from "../ABI/eqz_router_abi.json";


let owner: SignerWithAddress, otherAccounts: SignerWithAddress[], gaugeVault:SignerWithAddress;
// let Whale1: any = "0x08048f6d9db401d2716dcbb1979513231e5e3c81"; 
let usdc_ftm_whale = "0x3381b11f6865f23e0ad37a92b4cd4aebe9e4f86a"; // ftm network
let usdc_address = "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75";
let wFTM_address = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83";
let equal_address = "0x3Fd3A0c85B70754eFc07aC9Ac0cbBDCe664865A6";

let handler: any;
let eqz_USDC_WFTM_vault: any, eqz_USDC_WFTM_adapter: any;
let deepfiToken: any;
let testToken6: any, testToken18: any ;
let vUsdc_WFTM:any, wFTM:any, usdc:any, equal:any;

let eqz_router:any;

let initialBalance: String, onGoingBal: String;

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

    await eqz_USDC_WFTM_vault.connect(owner).setRewardsDuration(duration);
  }

  if (amount != undefined) {
    await deepfiToken.connect(owner).approve(eqz_USDC_WFTM_vault.address, amount)
    await eqz_USDC_WFTM_vault.connect(owner).notifyRewardAmount(amount);
  }
}

async function deposit(recipient: SignerWithAddress, token: Contract, amount: number) {
  // await token.connect(gaugeVault).transfer(recipient.address, amount);
  await token.connect(recipient).approve(eqz_USDC_WFTM_vault.address, amount);
  await eqz_USDC_WFTM_vault.connect(recipient).deposit(amount);

}

function getRandomNumber(min: number, max: number) {
  return Math.floor(Math.random() * (max - min) + min);
}

async function getLPTokens(dest:any, amount:BigNumber) {
        // convert ftm to wftm
        await wFTM.connect(owner).deposit({value: amount.mul(2)});
        //approve supply tokens
        await usdc.connect(owner).approve(eqz_router.address, amount )
        await wFTM.connect(owner).approve(eqz_router.address, amount.mul(2) )
        console.log('start supply ... ')
  
        let {amountA, amountB, liquidity} = await eqz_router.connect(owner).addLiquidity(
          usdc_address, //token A 
          wFTM_address, // token B 
          false, // stablecoin 
          amount, // amountADesired
          amount.mul(2), // amountBDesired
          1, // amountAmin
          1, // amountBmin
          dest.address, // to 
          Date.now() + 100000 // deadline
          )
}

describe("🌞 EQZ Adapter Test", async () => {
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
    owner = await getImpersonatedSigner(usdc_ftm_whale);
    eqz_router = await ethers.getContractAt(eqz_router_abi, '0x2aa07920E4ecb4ea8C801D9DFEce63875623B285')

    vUsdc_WFTM = await ethers.getContractAt(IERC20, '0x7547d05dFf1DA6B4A2eBB3f0833aFE3C62ABD9a1') // Lp token
    wFTM = await ethers.getContractAt(IERC20, wFTM_address)
    usdc = await ethers.getContractAt(IERC20, usdc_address)
    equal = await ethers.getContractAt(IERC20, equal_address)

    // await owner.sendTransaction({
    //   to: otherAccounts[0].address,
    //   value: ethers.utils.parseEther("100.0"), // Sends exactly 100.0 FTM
    // });

  });

  beforeEach(async () => {
    ({
      testToken6,
      testToken18,
      deepfiToken,
      handler,
      // mlpVault,
      // mlp_adapter,
      eqz_USDC_WFTM_vault,
      eqz_USDC_WFTM_adapter
    } = await deploy_hardhat(owner, vUsdc_WFTM));

  })

  describe("🌱 Check Vault / Adapter / Rewards", async () => {

    it("Test 1 : 1 user staking on 1000 reward / 60 days", async () => {
      await getLPTokens(owner, parseEther("1000"));
        console.log("bal of LP Token  => ", formatUnits(await vUsdc_WFTM.balanceOf(owner.address), 18), await vUsdc_WFTM.balanceOf(owner.address))
        
        await setReward(864000, parseEther("1000"));
        console.log('Start User Deposit')
      // await deposit(otherAccounts[0], vUsdc_WFTM, ethers.utils.parseUnits("1", 18));
      await deposit(owner, vUsdc_WFTM, await vUsdc_WFTM.balanceOf(owner.address));
      console.log('Deposits Done ')

      await skipDays(60);
      await eqz_USDC_WFTM_vault.connect(owner).claimReward();
      console.log('User Rewards Claimed ')

      await eqz_USDC_WFTM_adapter.connect(owner).claimReward();
      console.log('Adapter Rewards Claimed ')

      // await eqz_USDC_WFTM_vault.connect(otherAccounts[0]).withdraw(parseUnits("1", 18));
      await eqz_USDC_WFTM_vault.connect(owner).withdraw(await eqz_USDC_WFTM_vault.getStakeBalance(owner.address));
      console.log('Withdrawns Done ')

      // await eqz_USDC_WFTM_adapter.connect(owner).transferAdapterFTM(await ethers.provider.getBalance(eqz_USDC_WFTM_adapter.address));
      // console.log('FTM Transfered !')

      console.log("------------------------------------");
      console.log("Contract Balance of vUsdc_WFTM => ", formatUnits(await vUsdc_WFTM.balanceOf(eqz_USDC_WFTM_adapter.address), 18))
      console.log("Contract Balance of EQUAL => ", formatUnits(await equal.balanceOf(eqz_USDC_WFTM_adapter.address), 18));
      console.log("Contract Balance of FTM => ", formatUnits(await ethers.provider.getBalance(eqz_USDC_WFTM_adapter.address), 18));
      console.log("Contract Balance of wFTM => ", formatUnits(await wFTM.balanceOf(eqz_USDC_WFTM_adapter.address), 18));
      // console.log("Treasury FTM Balance => ", formatUnits(await ethers.provider.getBalance(await eqz_USDC_WFTM_adapter.treasury()), 18));
      // console.log("getAdapterAmount => ", (await eqz_USDC_WFTM_adapter.getAdapterAmount()));
      console.log("------------------------------------");

    });


        it("Test 2 :4 users staking 10/10/30/50% on 1000 reward / 60 days", async () => {
      await setReward(864000, parseEther("1000"));
      
      await getLPTokens(otherAccounts[0], parseEther("100"));
      await getLPTokens(otherAccounts[1], parseEther("100"));
      await getLPTokens(otherAccounts[2], parseEther("300"));
      await getLPTokens(otherAccounts[3], parseEther("500"));

      await deposit(otherAccounts[0], vUsdc_WFTM, await vUsdc_WFTM.balanceOf(otherAccounts[0].address));
      await deposit(otherAccounts[1], vUsdc_WFTM, await vUsdc_WFTM.balanceOf(otherAccounts[1].address));
      await deposit(otherAccounts[2], vUsdc_WFTM, await vUsdc_WFTM.balanceOf(otherAccounts[2].address));
      await deposit(otherAccounts[3], vUsdc_WFTM, await vUsdc_WFTM.balanceOf(otherAccounts[3].address));

      await skipDays(60);
      await eqz_USDC_WFTM_vault.connect(otherAccounts[0]).claimReward();
      await eqz_USDC_WFTM_vault.connect(otherAccounts[1]).claimReward();
      await eqz_USDC_WFTM_vault.connect(otherAccounts[2]).claimReward();
      await eqz_USDC_WFTM_vault.connect(otherAccounts[3]).claimReward();

      await eqz_USDC_WFTM_vault.connect(otherAccounts[0]).withdraw(await eqz_USDC_WFTM_vault.getStakeBalance(otherAccounts[0].address));
      await eqz_USDC_WFTM_vault.connect(otherAccounts[1]).withdraw(await eqz_USDC_WFTM_vault.getStakeBalance(otherAccounts[1].address));
      await eqz_USDC_WFTM_vault.connect(otherAccounts[2]).withdraw(await eqz_USDC_WFTM_vault.getStakeBalance(otherAccounts[2].address));
      await eqz_USDC_WFTM_vault.connect(otherAccounts[3]).withdraw(await eqz_USDC_WFTM_vault.getStakeBalance(otherAccounts[3].address));

      await eqz_USDC_WFTM_adapter.connect(owner).claimReward();
      await eqz_USDC_WFTM_adapter.connect(owner).transferAdapterFTM(await ethers.provider.getBalance(eqz_USDC_WFTM_adapter.address));
      console.log("------------------------------------");
      console.log("Contract Balance of vUsdc_WFTM => ", formatUnits(await vUsdc_WFTM.balanceOf(eqz_USDC_WFTM_adapter.address), 18))
      console.log("Contract Balance of EQUAL => ", formatUnits(await equal.balanceOf(eqz_USDC_WFTM_adapter.address), 18));
      console.log("Contract Balance of FTM => ", formatUnits(await ethers.provider.getBalance(eqz_USDC_WFTM_adapter.address), 18));
      console.log("Contract Balance of wFTM => ", formatUnits(await wFTM.balanceOf(eqz_USDC_WFTM_adapter.address), 18));
      // console.log("Treasury FTM Balance => ", formatUnits(await ethers.provider.getBalance(await eqz_USDC_WFTM_adapter.treasury()), 18));
      // console.log("getAdapterAmount => ", (await eqz_USDC_WFTM_adapter.getAdapterAmount()));
      console.log("------------------------------------");

    });


  });

});

