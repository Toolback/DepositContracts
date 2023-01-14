// import { ethers } from "hardhat";

// async function main() {
//   const currentTimestampInSeconds = Math.round(Date.now() / 1000);
//   const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
//   const unlockTime = currentTimestampInSeconds + ONE_YEAR_IN_SECS;

//   const lockedAmount = ethers.utils.parseEther("1");

//   const Lock = await ethers.getContractFactory("Lock");
//   const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

//   await lock.deployed();

//   console.log(`Lock with 1 ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`);
// }

// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });



import { ethers, upgrades } from "hardhat"

async function deployProtocol() {
  // const gnosis = "0x2580f9954529853Ca5aC5543cE39E9B5B1145135";
  const gnosis = "0x25b3d91e2cbAe2397749f2F9A5598366Df26fA49";

  // Defi Token
  const DefiToken = await ethers.getContractFactory("DefiToken");

  let erc20 = await upgrades.deployProxy(DefiToken,
        [],
        {initializer: 'initialize', kind:'uups'}
  );
  console.log("DefiToken upgradable deployed to:", erc20.address);

  
  // Liquidity Handler
  const Handler = await ethers.getContractFactory("LiquidityHandler");

  let handler = await upgrades.deployProxy(Handler,
        [gnosis, erc20.address],
        {initializer: 'initialize', kind:'uups'}
  );

  console.log("Handler upgradable deployed to:", handler.address);

    // TokenHub
    const TokenHub = await ethers.getContractFactory("TokenHub");

    let hub = await upgrades.deployProxy(TokenHub,
          [gnosis, handler.address],
          {initializer: 'initialize', kind:'uups'}
    );
  
    console.log("TokenHub upgradable deployed to:", hub.address);
}

deployProtocol()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

export default deployProtocol;
//npx hardhat run scripts/deploy/deployHandler.ts --network polygon
//npx hardhat verify 0xb647c6fe9d2a6e7013c7e0924b71fa7926b2a0a3 --network polygon