import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat"
import { BigNumber, Contract } from "ethers";
import { formatUnits, parseEther, parseUnits } from "@ethersproject/units";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import deploy_hardhat from "../scripts/deploy_hardhat";
const IERC20 = require("../ABI/ERC20Abi.json")
var assert = require('chai').assert

let owner: SignerWithAddress, otherAccounts: SignerWithAddress[];
let fsMLPWhale1: any = "0xce52c2e8e54cc717d1b35ac730406141ddccb47d";
let fsMLPWhale2: any = "0x08048f6d9db401d2716dcbb1979513231e5e3c81";

let handler: any;
let mlpVault: any;
let mlp_adapter: any;
let deepfiToken: any;
let stakedGLP: any;
let testToken6: any;
let testToken18: any;

let testVault6: any;
let testAdapter6: any;

let testVaultMulti: any;

let testVault18: any;
let testAdapter18: any;

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


async function setReward(vault: any, duration?: number, amount?: BigNumber) {
  if (duration != undefined) {
    await vault.connect(owner).setRewardsDuration(duration);
  }
  if (amount != undefined) {
    await deepfiToken.connect(owner).approve(vault.address, amount)
    await vault.connect(owner).notifyRewardAmount(amount);
  }
}

async function setMultiReward(vault: any, token:any, duration?: number, amount?: BigNumber) {
  if (duration != undefined) {
    await vault.connect(owner).setRewardsDuration(duration, token.address);
  }
  if (amount != undefined) {
    await token.connect(owner).approve(vault.address, amount)
    await vault.connect(owner).notifyRewardAmount(amount, token.address);
  }
}

async function deposit(recipient: SignerWithAddress, token: Contract, vault: any, amount: BigNumber) {
  await token.connect(owner).transfer(recipient.address, amount);
  await token.connect(recipient).approve(vault.address, amount);
  await vault.connect(recipient).deposit(amount);
}

function getRandomNumber(min: number, max: number) {
  return Math.floor(Math.random() * (max - min) + min);
}

describe("🌞 Protocol Features Test", async () => {
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
    stakedGLP = await ethers.getContractAt(IERC20, '0xfdc9b5be032216315bbe8c06b1c4f563d1689b85')
  });

  beforeEach(async () => {
    ({
      testToken6,
      testToken18,
      deepfiToken,
      handler,
      mlpVault,
      mlp_adapter
    } = await deploy_hardhat(owner, stakedGLP));


    // Test Vault6
    const TESTVault6 = await ethers.getContractFactory("D_Vault_SingleReward");
    testVault6 = await upgrades.deployProxy(TESTVault6,
      //vault name, staking token, reward token, admin, handler, trusted forwarder
      ["test6", testToken6.address, deepfiToken.address, owner.address, handler.address],
      { initializer: 'initialize', kind: 'uups' }
    );
    // Test Adapter6
    const MLPAdapter6 = await ethers.getContractFactory("testAdapter");
    let testAdapter6 = await upgrades.deployProxy(MLPAdapter6,
      // treasury / handler / staking token / reward token / admin
      [owner.address, handler.address, testToken6.address, deepfiToken.address, owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );
    // const adapterId = await handler.getLastAdapterIndex();
    const adapterId = 3;
    await handler.connect(owner).setPoolToAdapterId(testVault6.address, adapterId);
    await handler.connect(owner).setAdapter(adapterId, "test Strategy 6 decimals", 0, testAdapter6.address, true);
    // await handler.grantRole(handler.DEFAULT_ADMIN_ROLE(), pool_usdc.address);
    await deepfiToken.connect(owner).transfer(testVault6.address, ethers.utils.parseEther("1000000"))


    // Test Vault18
    const TESTVault18 = await ethers.getContractFactory("D_Vault_SingleReward");
    testVault18 = await upgrades.deployProxy(TESTVault18,
      //staking token, reward token, admin, handler, trusted forwarder
      ["test18", testToken18.address, deepfiToken.address, owner.address, handler.address],
      { initializer: 'initialize', kind: 'uups' }
    );
    const TESTAdapter18 = await ethers.getContractFactory("testAdapter");
    let testAdapter18 = await upgrades.deployProxy(TESTAdapter18,
      // treasury / handler / staking token / reward token / admin
      [owner.address, handler.address, testToken18.address, deepfiToken.address, owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );
    // const adapterId = await handler.getLastAdapterIndex();
    const adapterId2 = 4;
    await handler.connect(owner).setPoolToAdapterId(testVault18.address, adapterId2);
    await handler.connect(owner).setAdapter(adapterId2, "test Strategy 18 decimals", 0, testAdapter18.address, true);
    // await handler.grantRole(handler.DEFAULT_ADMIN_ROLE(), pool_usdc.address);
  

    // Test Multi Reward Vault
    let rewardTokens = [deepfiToken.address, testToken18.address, testToken6.address]
    const TESTVaultMulti = await ethers.getContractFactory("D_Vault_MultiRewards");
    testVaultMulti = await upgrades.deployProxy(TESTVaultMulti,
      //staking token, reward token, admin, handler, trusted forwarder
      ["multiRewardVault", stakedGLP.address, rewardTokens, owner.address, handler.address],
      { initializer: 'initialize', kind: 'uups' }
    );
    // const TESTAdapter18 = await ethers.getContractFactory("testAdapter");
    // let testAdapter = await upgrades.deployProxy(TESTAdapter18,
    //   // treasury / handler / staking token / reward token / admin
    //   [owner.address, handler.address, testToken18.address, deepfiToken.address, owner.address],
    //   { initializer: 'initialize', kind: 'uups' }
    // );
    // const adapterId = await handler.getLastAdapterIndex();
    await handler.connect(owner).setPoolToAdapterId(testVaultMulti.address, 1);
    // await handler.connect(owner).setAdapter(adapterId2, "test Strategy 18 decimals", 0, testAdapter18.address, true);

  })

  describe("🌱 Check Upgradeablility of Contracts ", async () => {
    it("Test : Upgrade Vault Contract", async () => {
      let currentMLPVault = await ethers.getContractAt("D_Vault_SingleReward", mlpVault.address);
      await currentMLPVault.connect(owner).grantRole("0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3", "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      await currentMLPVault.connect(owner).changeUpgradeStatus(true);
      // deposit 100 mlp to ensure balance are secured during upgrade
      await deposit(owner, stakedGLP, mlpVault, ethers.utils.parseUnits("100", 18));
      const balBefore = formatUnits((await mlpVault.getStakeBalance(owner.address)).toString(), 18);
      const NewUsdcPool = await ethers.getContractFactory("test_update_pool");
      // let UsdcPool = await upgrades.forceImport(mlpVault.address, NewUsdcPool);
      const poolv2 = await upgrades.upgradeProxy(mlpVault, NewUsdcPool);

      // console.log("------------------------------------");
      // console.log("bal w deposits before upgrade", balBefore);
      // console.log("Upgrade complete => ", await poolv2.version());
      // console.log("bal after upgrade", formatUnits((await poolv2.getStakeBalance(owner.address)).toString(), 18));
      await poolv2.connect(owner).withdraw(parseEther("50"));
      // console.log("bal after upgrade and sub 50 =>", formatUnits((await poolv2.getStakeBalance(owner.address)).toString(), 18));
      // console.log("------------------------------------");

      expect(formatUnits((await poolv2.getStakeBalance(owner.address)).toString(), 18)).to.be.equal("50.0")
    });
  })


  describe("🌱 Check Adapters Datas ", async () => {
    it("Test : Add Adapter Contract Infos", async () => {
      let contractInfo = {
        name: "test",
        description: "Test Strategy",
        link: "http"
      }
      await handler.connect(owner).addContractInfoToAdapterInfo(1, contractInfo);
      // console.log("------------------------------------");
      // console.log("nb of contracts info => ", (await handler.getAdapterInfo(1)).contracts.length)
      // console.log("------------------------------------");
      expect(((await handler.getAdapterInfo(1)).contracts).length).to.be.equal(1);
    });
  });

    describe("🌱 Check Pool Functionality", async () => {
      it("Test Security Contract Pausable", async () => {
        await deposit(owner, testToken18, testVault18, ethers.utils.parseUnits("100", 18));
        await testVault18.connect(owner).pause();

        console.log("------------------------------------");
        console.log("Contract Pause State => ", await testVault18.connect(owner).paused())
        console.log("------------------------------------");
        //should revert =>
        // await deposit(owner, stakedGLP, ethers.utils.parseUnits("100", 18));
        // expect(await deposit(owner, stakedGLP, ethers.utils.parseUnits("100", 18))).to.throw();
      })

      it("Test Vault Deposit", async () => {
        initialBalance = formatUnits((await testToken18.balanceOf(owner.address)).toString(), 18);
        await deposit(owner, testToken18, testVault18, ethers.utils.parseUnits("100", 18));
        onGoingBal = formatUnits((await testToken18.balanceOf(owner.address)).toString(), 18);
        expect(Math.round(Number(onGoingBal))).to.be.equal(Math.round(Number(initialBalance)) - 100);
        expect(Math.round(Number(formatUnits((await testVault18.getStakeBalance(owner.address)).toString(), 18)))).to.be.equal(100)
      })

      it("Test Vault Withdraw", async () => {
        await deposit(owner, testToken18, testVault18, ethers.utils.parseUnits("100", 18));
        let stakingBal = Math.round(Number(formatUnits((await testVault18.balanceOf(owner.address)).toString(), 18)));
        let tokenBal = Math.round(Number(formatUnits((await testToken18.balanceOf(owner.address)).toString(), 18)));
        await testVault18.connect(owner).withdraw(parseUnits("100", 18));
        let stakingBalAfter = Math.round(Number(formatUnits((await testVault18.balanceOf(owner.address)).toString(), 18)));
        let tokenBalAfter = Math.round(Number(formatUnits((await testToken18.balanceOf(owner.address)).toString(), 18)));

        expect(stakingBalAfter).to.be.equal(stakingBal - 100);
        expect(tokenBalAfter).to.be.equal(tokenBal + 100);
      })

      it("Test Vault Deposit / Withdraw / Claim", async () => {
        await setReward(testVault18, 864000, parseEther("1000"));

        let rewardBal = Math.round(Number(formatUnits((await deepfiToken.balanceOf(owner.address)).toString(), 18)));
        await deposit(owner, testToken18, testVault18, ethers.utils.parseUnits("100", 18));
        let stakingBal = Math.round(Number(formatUnits((await testVault18.balanceOf(owner.address)).toString(), 18)));
        let tokenBal = Math.round(Number(formatUnits((await testToken18.balanceOf(owner.address)).toString(), 18)));
          await skipDays(15);
        await testVault18.connect(owner).withdraw(parseUnits("100", 18));
        await testVault18.connect(owner).claimReward();
        let stakingBalAfter = Math.round(Number(formatUnits((await testVault18.balanceOf(owner.address)).toString(), 18)));
        let tokenBalAfter = Math.round(Number(formatUnits((await testToken18.balanceOf(owner.address)).toString(), 18)));
        let rewardBalAfter = Math.round(Number(formatUnits((await deepfiToken.balanceOf(owner.address)).toString(), 18)));
        expect(stakingBalAfter).to.be.equal(stakingBal - 100);
        expect(tokenBalAfter).to.be.equal(tokenBal + 100);
        expect(rewardBalAfter).to.be.above(rewardBal + 999);
      })
  });


  describe("🌱 Check Vault 6 decimals Reward Distribution ", async () => {

    it("Test 1 : 1 user staking 100% tvl on 1000 reward / 10 days", async () => {
      await setReward(testVault6, 864000, parseEther("1000"));
      await deposit(otherAccounts[0], testToken6, testVault6, ethers.utils.parseUnits("100", 6));
      await skipDays(15);
      await testVault6.connect(otherAccounts[0]).withdraw(parseUnits("100", 6));
      await testVault6.connect(otherAccounts[0]).claimReward();
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[0].address), 18))).is.above(999)
    });

    it("Test 2 : 4 users staking 10/10/30/50% on 1000 reward", async () => {
      await setReward(testVault6, 864000, parseEther("1000"));

      await deposit(otherAccounts[0], testToken6, testVault6, ethers.utils.parseUnits("100", 6));
      await deposit(otherAccounts[1], testToken6, testVault6, ethers.utils.parseUnits("100", 6));
      await deposit(otherAccounts[2], testToken6, testVault6, ethers.utils.parseUnits("300", 6));
      await deposit(otherAccounts[3], testToken6, testVault6, ethers.utils.parseUnits("500", 6));

      await skipDays(15);
      await testVault6.connect(otherAccounts[0]).claimReward();
      await testVault6.connect(otherAccounts[1]).claimReward();
      await testVault6.connect(otherAccounts[2]).claimReward();
      await testVault6.connect(otherAccounts[3]).claimReward();

      await testVault6.connect(otherAccounts[0]).withdraw(parseUnits("100", 6));
      await testVault6.connect(otherAccounts[1]).withdraw(parseUnits("100", 6));
      await testVault6.connect(otherAccounts[2]).withdraw(parseUnits("300", 6));
      await testVault6.connect(otherAccounts[3]).withdraw(parseUnits("500", 6));

      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[0].address), 18))).is.above(99)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[1].address), 18))).is.above(99)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[2].address), 18))).is.above(299)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[3].address), 18))).is.above(499)
    });
  });

  describe("🌱 Check Vault 18 decimals Reward Distribution ", async () => {

    it("Test 1 : 1 user staking 100% tvl on 1000 reward / 10 days", async () => {
      await setReward(testVault18, 864000, parseEther("1000"));
      await deposit(otherAccounts[0], testToken18, testVault18, ethers.utils.parseUnits("100", 18));
      await skipDays(15);
      await testVault18.connect(otherAccounts[0]).withdraw(parseUnits("100", 18));
      await testVault18.connect(otherAccounts[0]).claimReward();
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[0].address), 18))).is.above(999)
    });

    it("Test 2 : 4 users staking 10/10/30/50% on 1000 reward", async () => {
      await setReward(testVault18, 864000, parseEther("1000"));

      await deposit(otherAccounts[0], testToken18, testVault18, ethers.utils.parseUnits("100", 18));
      await deposit(otherAccounts[1], testToken18, testVault18, ethers.utils.parseUnits("100", 18));
      await deposit(otherAccounts[2], testToken18, testVault18, ethers.utils.parseUnits("300", 18));
      await deposit(otherAccounts[3], testToken18, testVault18, ethers.utils.parseUnits("500", 18));

      await skipDays(15);

      await testVault18.connect(otherAccounts[0]).claimReward();
      await testVault18.connect(otherAccounts[1]).claimReward();
      await testVault18.connect(otherAccounts[2]).claimReward();
      await testVault18.connect(otherAccounts[3]).claimReward();

      await testVault18.connect(otherAccounts[0]).withdraw(parseUnits("100", 18));
      await testVault18.connect(otherAccounts[1]).withdraw(parseUnits("100", 18));
      await testVault18.connect(otherAccounts[2]).withdraw(parseUnits("300", 18));
      await testVault18.connect(otherAccounts[3]).withdraw(parseUnits("500", 18));

      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[0].address), 18))).is.above(99)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[1].address), 18))).is.above(99)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[2].address), 18))).is.above(299)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[3].address), 18))).is.above(499)
    });
  });



  describe("🌱 Check Multi Rewards Vault", async () => {

    it("Test 1 : 1 user staking 100% tvl on 1000 reward / 10 days", async () => {
      await setMultiReward(testVaultMulti, deepfiToken, 864000, parseEther("1000"));
      await setMultiReward(testVaultMulti, testToken18, 864000, parseEther("500"));
      await setMultiReward(testVaultMulti, testToken6, 864000, parseUnits("300", 6));

      await deposit(otherAccounts[0], stakedGLP, testVaultMulti, ethers.utils.parseUnits("100", 18));

      await skipDays(15);
      await testVaultMulti.connect(otherAccounts[0]).withdraw(parseUnits("100", 18));
      await testVaultMulti.connect(otherAccounts[0]).claimReward();

      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[0].address), 18))).is.above(999)
      expect(Number(formatUnits(await testToken18.balanceOf(otherAccounts[0].address), 18))).is.above(499)
      expect(Number(formatUnits(await testToken6.balanceOf(otherAccounts[0].address), 6))).is.above(299)
    });

    it("Test 2 : 4 users staking 10/10/30/50% on 1000 reward", async () => {
      await setMultiReward(testVaultMulti, deepfiToken, 864000, parseEther("1000"));
      await setMultiReward(testVaultMulti, testToken18, 864000, parseEther("1000"));
      await setMultiReward(testVaultMulti, testToken6, 864000, parseUnits("1000", 6));

      await deposit(otherAccounts[0], stakedGLP, testVaultMulti, ethers.utils.parseUnits("100", 18));
      await deposit(otherAccounts[1], stakedGLP, testVaultMulti, ethers.utils.parseUnits("100", 18));
      await deposit(otherAccounts[2], stakedGLP, testVaultMulti, ethers.utils.parseUnits("300", 18));
      await deposit(otherAccounts[3], stakedGLP, testVaultMulti, ethers.utils.parseUnits("500", 18));

      await skipDays(15);

      await testVaultMulti.connect(otherAccounts[0]).claimReward();
      await testVaultMulti.connect(otherAccounts[1]).claimReward();
      await testVaultMulti.connect(otherAccounts[2]).claimReward();
      await testVaultMulti.connect(otherAccounts[3]).claimReward();

      await testVaultMulti.connect(otherAccounts[0]).withdraw(parseUnits("100", 18));
      await testVaultMulti.connect(otherAccounts[1]).withdraw(parseUnits("100", 18));
      await testVaultMulti.connect(otherAccounts[2]).withdraw(parseUnits("300", 18));
      await testVaultMulti.connect(otherAccounts[3]).withdraw(parseUnits("500", 18));

      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[0].address), 18))).is.above(99)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[1].address), 18))).is.above(99)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[2].address), 18))).is.above(299)
      expect(Number(formatUnits(await deepfiToken.balanceOf(otherAccounts[3].address), 18))).is.above(499)
    
      expect(Number(formatUnits(await testToken18.balanceOf(otherAccounts[0].address), 18))).is.above(99)
      expect(Number(formatUnits(await testToken18.balanceOf(otherAccounts[1].address), 18))).is.above(99)
      expect(Number(formatUnits(await testToken18.balanceOf(otherAccounts[2].address), 18))).is.above(299)
      expect(Number(formatUnits(await testToken18.balanceOf(otherAccounts[3].address), 18))).is.above(499)

      expect(Number(formatUnits(await testToken6.balanceOf(otherAccounts[0].address), 6))).is.above(99)
      expect(Number(formatUnits(await testToken6.balanceOf(otherAccounts[1].address), 6))).is.above(99)
      expect(Number(formatUnits(await testToken6.balanceOf(otherAccounts[2].address), 6))).is.above(299)
      expect(Number(formatUnits(await testToken6.balanceOf(otherAccounts[3].address), 6))).is.above(499)



    });
  });
});

