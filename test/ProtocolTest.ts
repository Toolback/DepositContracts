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

let hub: Contract;
let handler: Contract;
let IbUsdc: Contract;
let DToken: Contract;
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

    DToken = await upgrades.deployProxy(DefiToken,
      [owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );
    // console.log("DefiToken upgradable deployed to:", DToken.address);


    // Liquidity Handler
    const Handler = await ethers.getContractFactory("LiquidityHandler");

    handler = await upgrades.deployProxy(Handler,
      [owner.address, DToken.address],
      { initializer: 'initialize', kind: 'uups' }
    );

    // console.log("Handler upgradable deployed to:", handler.address);

    const IBToken = await ethers.getContractFactory("DefiLP");

    IbUsdc = await upgrades.deployProxy(IBToken,
      ["IbUsdc", "IbUsdc", usdc_polygon_address, owner.address, handler.address, 10, owner.address],
      { initializer: 'initialize', kind: 'uups' }
    );

    // console.log("Handler upgradable deployed to:", handler.address);

    handler.connect(owner).addToken(IbUsdc.address);
    handler.connect(owner).grantRole(handler.DEFAULT_ADMIN_ROLE(), IbUsdc.address);
    expect((await handler.getDeployedTokens())[0]).to.be.equal(IbUsdc.address)

  });


  describe("--> Test Started", async () => {
  it("Admin should deposit Gov Token to Liquidity Handler for claimable staking reward", async () => {
    await DToken.connect(owner).transfer(handler.address, parseEther("1000000"))
    expect(ethers.utils.formatUnits((await DToken.balanceOf(handler.address)).toString(), 18)).to.be.equal("1000000.0");
  });

  it("User should be able to deposit underlying and mint LPToken", async () => {
    await usdcPolygon.connect(owner).approve(IbUsdc.address, (100 * 10 ** 6))
    await IbUsdc.connect(owner).deposit(100 * 10 ** 6);
    expect((await IbUsdc.balanceOf(owner.address)).toString()).to.be.equal(ethers.utils.parseUnits("100", 6))
  });

  it("Should check user claimable reward", async () => {
        // Conversion de l'APR en taux d'intérêt journalier
        let aprSeconds = (10 / 365) / 86400;
        let apr2 = 10/365/24/60/60;

        console.log("RETURNED APR / SEC", aprSeconds)
        console.log("RETURNED APR / SEC", apr2)

    console.log("reward after 0days => ", await IbUsdc.getReward(owner.address));

  // advance time by one hour and mine a new block
    // await time.increase(3000000);
    await skipDays(30);

    console.log("reward after 30days => ", await IbUsdc.getReward(owner.address));

    await skipDays(30);
    console.log("reward after 60days => ", ethers.utils.formatUnits(await IbUsdc.getReward(owner.address), 6));

    let maxClaim = await IbUsdc.getReward(owner.address);
    await IbUsdc.connect(owner).requestRewards(maxClaim);
    
    console.log("returned claim bal => ", await DToken.balanceOf(owner.address));
    
    console.log("before final lp bal => ", ethers.utils.formatUnits(await IbUsdc.balanceOf(owner.address), 6));
    await IbUsdc.connect(owner).withdrawTo(owner.address, 100 * 10 ** 6);
    console.log("final lp bal => ", ethers.utils.formatUnits(await IbUsdc.balanceOf(owner.address), 6));
    console.log("final claimed bal => ", ethers.utils.formatUnits(await DToken.balanceOf(owner.address), 18));

    // expect(ethers.utils.formatUnits((await DToken.balanceOf(handler.address)).toString(), 18)).to.be.equal("1000000.0");
  });
  
  })
  
});





