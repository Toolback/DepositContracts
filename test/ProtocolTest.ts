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
let fsMLPWhale2:any = "0xce52c2e8e54cc717d1b35ac730406141ddccb47d";
let fsMLPWhale1:any = "0x08048f6d9db401d2716dcbb1979513231e5e3c81";
let fsMLPWhale3:any = "0xaa042a7010fc42bed6d33bd4702e8ec28af8ba48";
let polygonWhale:any = "0xd5c08681719445a5fdce2bda98b341a49050d821"

let handler: Contract;
let mlpVault: Contract;
let mlp_adapter: Contract;
let defiToken: Contract;
let fsMLP: any;

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
  console.log('!enter deposit ')
  if (recipient != owner)
  {
    await token.connect(owner).transfer(recipient.address, amount);
    console.log('!enter deposit1 ')
  }

  await token.connect(recipient).approve(mlpVault.address, amount);
  console.log('!enter deposit2 ')

  await mlpVault.connect(recipient).deposit(amount);
  console.log('!enter deposit 3')

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
    owner = await getImpersonatedSigner(fsMLPWhale1);
    // console.log("admin address is", owner.address);

    // MLP 
    fsMLP = await ethers.getContractAt(IERC20, '0xFfB69477FeE0DAEB64E7dE89B57846aFa990e99C')

  });

  beforeEach(async () => {
    // Defi Token
    const DefiToken = await ethers.getContractFactory("DeepfiToken");
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

    // MLP Vault
    const MlpVault = await ethers.getContractFactory("D_Vault_SingleReward");
    mlpVault = await upgrades.deployProxy(MlpVault,
      ["MLP", fsMLP.address, defiToken.address, owner.address, handler.address],
      { initializer: 'initialize', kind: 'uups' }
    );

    // Mlp Adapter
    const MlpAdapter = await ethers.getContractFactory("MlpAdapter");
    mlp_adapter = await upgrades.deployProxy(MlpAdapter,
      [handler.address, fsMLP.address, defiToken.address, owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );

    // const adapterId = await handler.getLastAdapterIndex();
    const adapterId = 1;
    await handler.connect(owner).setPoolToAdapterId(mlpVault.address, adapterId);
    await handler.connect(owner).setAdapter(adapterId, "Mummy Finance - MLP Strategy", 0, mlp_adapter.address, true);
    // await handler.connect(owner).grantRole(handler.DEFAULT_ADMIN_ROLE(), mlpVault.address);
    expect((await handler.getListOfPools())[0]).to.be.equal(mlpVault.address)
    await defiToken.connect(owner).transfer(mlpVault.address, parseEther("1000000"))
    expect(ethers.utils.formatUnits((await defiToken.balanceOf(mlpVault.address)).toString(), 18)).to.be.equal("1000000.0");
  })





  describe("☄ Check Upgradeablility of Contracts ", async () => {
    // it("Test 1 : Upgrade Defi Token Contract", async () => {
    // });
    // it("Test 2 : Upgrade Liquidity Handler Contract", async () => {
    // });
    it("Test : Upgrade Pool Contract", async () => {
      let currentUsdcPool = await ethers.getContractAt("D_Vault_SingleReward", mlpVault.address);
      await currentUsdcPool.connect(owner).grantRole("0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3", "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      await currentUsdcPool.connect(owner).changeUpgradeStatus(true);
      await deposit(owner, fsMLP, ethers.utils.parseUnits("100", 18));
      const balBefore = formatUnits((await mlpVault.getStakeBalance(owner.address)).toString(), 18);
      const NewUsdcPool = await ethers.getContractFactory("test_update_pool");
      // let UsdcPool = await upgrades.forceImport(mlpVault.address, NewUsdcPool);
      const poolv2 = await upgrades.upgradeProxy(mlpVault, NewUsdcPool);

      console.log("------------------------------------");
      console.log("bal w deposits before upgrade", balBefore);
      console.log("Upgrade complete => ", await poolv2.version());
      console.log("bal after upgrade", formatUnits((await poolv2.getStakeBalance(owner.address)).toString(), 18));
      await poolv2.connect(owner).withdraw(50 * 10 ** 18);
      console.log("bal after upgrade and sub 50 =>", formatUnits((await poolv2.getStakeBalance(owner.address)).toString(), 18));
      console.log("------------------------------------");
    });
  })


  // describe("☄ Check Datas ", async () => {

  //   it("Test : Add Adapter Infos", async () => {
  //     let contractInfo = {
  //       name: "MLP",
  //       description: "Test Strategy",
  //       link: "http"
  //     }
  //     console.log("info Before => ", await handler.getAdapterInfo(1))

  //     await handler.connect(owner).addContractInfoToAdapterInfo(1, contractInfo);

  //     console.log("------------------------------------");
  //     console.log("info retrieved (should have MLP) => ", await handler.getAdapterInfo(1))
  //     console.log("------------------------------------");
  //   });


  describe("☄ TEST Claim MLP ", async () => {

    it("Test : retrieving bal Infos", async () => {

      console.log("info Before => ", )

      
      console.log("------------------------------------");
        console.log("test Balance fsMLP whale1 ",  ethers.utils.formatUnits(await fsMLP.balanceOf(fsMLPWhale1), 18))
        console.log("test Balance fsMLP whale1 ",  ethers.utils.formatUnits(await fsMLP.balanceOf(fsMLPWhale2), 18))
        console.log("test Balance fsMLP whale1 ",  ethers.utils.formatUnits(await fsMLP.balanceOf(fsMLPWhale3), 18))
      console.log("------------------------------------");
    });

  })
  

  //   describe("☄ Check Pool Functionality", async () => {
  //     // it("Test Security Contract Pausable", async () => {
  //     //   await deposit(owner, fsMLP, ethers.utils.parseUnits("100", 18));
  //     //   await mlpVault.connect(owner).pause();
  //     //   console.log("Paused HERE ?", await mlpVault.connect(owner).paused())
  //     //   await deposit(owner, fsMLP, ethers.utils.parseUnits("100", 18));
  //     // })
  //     it("Test 1 : 1 user staking 100% tvl on 1000 reward / 10 days", async () => {
  //       await setReward(864000, parseEther("1000"));

  //       initialBalance = ethers.utils.formatUnits(await fsMLP.balanceOf(owner.address), 18);
  //       // await fsMLP.connect(owner).approve(mlpVault.address, (100 * 10 ** 18))
  //       // await mlpVault.connect(owner).deposit(100 * 10 ** 18);
  //       await deposit(owner, fsMLP, ethers.utils.parseUnits("100", 18));
  //       onGoingBal = ethers.utils.formatUnits(await fsMLP.balanceOf(owner.address), 18);


  //       console.log("reward after 0days => ", ethers.utils.formatUnits(await mlpVault.getRewardBalance(owner.address), 18));
  //       // advance time by one hour and mine a new block
  //       // await time.increase(3000000);
  //       await skipDays(2);

  //       console.log("reward after 2days => ", ethers.utils.formatUnits(await mlpVault.getRewardBalance(owner.address), 18));

  //       await skipDays(2);
  //       console.log("reward after 4days => ", ethers.utils.formatUnits(await mlpVault.getRewardBalance(owner.address), 18));
  //       await skipDays(15);

  //       // let maxClaim = await mlpVault.getRewardBalance(owner.address);
  //       await mlpVault.connect(owner).claimReward();

  //       console.log("returned claim bal => ", await defiToken.balanceOf(owner.address));
  //       console.log("------------------------------------");

  //       await mlpVault.connect(owner).withdraw(100 * 10 ** 18);
  //       console.log("initial MLP bal => ", initialBalance);
  //       console.log("ongoing MLP Balance (staking)  => ", onGoingBal);
  //       console.log("final MLP bal => ", ethers.utils.formatUnits(await fsMLP.balanceOf(owner.address), 18));

  //       console.log("final Defi earned bal => ", ethers.utils.formatUnits(await defiToken.balanceOf(owner.address), 18));
  //       console.log("MLP OWNER BAL => ", ethers.utils.formatUnits(await fsMLP.balanceOf(owner.address), 18));

  //       console.log("------------------------------------");

  //       // expect(ethers.utils.formatUnits((await DToken.balanceOf(handler.address)).toString(), 18)).to.be.equal("1000000.0");
  //     });

  //     it("Test 2 : 4 users staking 10/10/30/50% on 1000 reward", async () => {
  //       await setReward(864000, parseEther("1000"));

  //       await deposit(otherAccounts[1], fsMLP, parseUnits("100", 18));
  //       await deposit(otherAccounts[2], fsMLP, parseUnits("100", 18));
  //       await deposit(otherAccounts[3], fsMLP, parseUnits("300", 18));
  //       await deposit(otherAccounts[4], fsMLP, parseUnits("500", 18));

  //       await skipDays(15);

  //       await mlpVault.connect(otherAccounts[1]).withdraw(parseUnits("100", 18));
  //       await mlpVault.connect(otherAccounts[2]).withdraw(parseUnits("100", 18));
  //       await mlpVault.connect(otherAccounts[3]).withdraw(parseUnits("300", 18));
  //       await mlpVault.connect(otherAccounts[4]).withdraw(parseUnits("500", 18));

  //       await mlpVault.connect(otherAccounts[1]).claimReward();
  //       await mlpVault.connect(otherAccounts[2]).claimReward();
  //       await mlpVault.connect(otherAccounts[3]).claimReward();
  //       await mlpVault.connect(otherAccounts[4]).claimReward();

  //       console.log("------------------------------------");
  //       console.log("final Defi earned bal user 1 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[1].address), 18));
  //       console.log("final Defi earned bal user 2 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[2].address), 18));
  //       console.log("final Defi earned bal user 3 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[3].address), 18));
  //       console.log("final Defi earned bal user 4 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[4].address), 18));
  //       console.log("------------------------------------");
  //     });


  //     it("Test 3 : multiple / random users and values on 1000 reward", async () => {
  //     let numberOfDeposits = getRandomNumber(4, 5);
  //     let i = 0;

  //     await setReward(864000, parseEther("1000"));

  //     while (i <= numberOfDeposits) {
  //         await deposit(otherAccounts[1], fsMLP, parseUnits((getRandomNumber(500, 10000)).toString(), 18));
  //         await deposit(otherAccounts[2], fsMLP, parseUnits((getRandomNumber(500, 10000)).toString(), 18));
  //         await deposit(otherAccounts[3], fsMLP, parseUnits((getRandomNumber(500, 10000)).toString(), 18));
  //         i++;
  //     }
  //     await skipDays(1);
  //     i = 0;
  //     let numberOfWithdrawals = getRandomNumber(3, 4);

  //     while (i <= numberOfWithdrawals / 3) {
  //         await mlpVault.connect(otherAccounts[1]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 18));
  //         await mlpVault.connect(otherAccounts[2]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 18));
  //         await mlpVault.connect(otherAccounts[3]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 18));
  //         i++;
  //     }
  //     await skipDays(3);
  //     // i = 0;

  //     while (i <= numberOfWithdrawals) {
  //         await mlpVault.connect(otherAccounts[1]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 18));
  //         await mlpVault.connect(otherAccounts[2]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 18));
  //         await mlpVault.connect(otherAccounts[3]).withdraw(parseUnits((getRandomNumber(100, 500)).toString(), 18));
  //         i++;
  //     }

  //     await skipDays(10);

  //     await mlpVault.connect(otherAccounts[1]).withdraw(await mlpVault.connect(otherAccounts[1]).getStakeBalance(otherAccounts[1].address));
  //     await mlpVault.connect(otherAccounts[2]).withdraw(await mlpVault.connect(otherAccounts[2]).getStakeBalance(otherAccounts[2].address));
  //     await mlpVault.connect(otherAccounts[3]).withdraw(await mlpVault.connect(otherAccounts[3]).getStakeBalance(otherAccounts[3].address));

  //     await mlpVault.connect(otherAccounts[1]).claimReward();
  //     await mlpVault.connect(otherAccounts[2]).claimReward();
  //     await mlpVault.connect(otherAccounts[3]).claimReward();

  //     console.log("------------------------------------");
  //     console.log("final Defi earned bal user 1 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[1].address), 18));
  //     console.log("final Defi earned bal user 2 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[2].address), 18));
  //     console.log("final Defi earned bal user 3 => ", ethers.utils.formatUnits(await defiToken.balanceOf(otherAccounts[3].address), 18));
  //     console.log("------------------------------------");
  //   })

  // });

});