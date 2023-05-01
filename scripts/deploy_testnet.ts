import { ethers, upgrades } from "hardhat"

async function deploy_testnet() {
  const gnosis = "0x4a8cF400cd00D54C784D910571Da49a4e4F3c866"; // privatekey
  //   const gnosis = "0xe76c64A113da0fF58D31C2b7A6F7168d842E5912"; //mnemo

  // Test Token (only for testnet)
  const testToken1 = await ethers.getContractFactory("FakeToken");

  let testtoken1 = await upgrades.deployProxy(testToken1,
    [gnosis, 18],
    { initializer: 'initialize', kind: 'uups' }
  );

  console.log("Test Token 1 (18 decimals) deployed to:", testtoken1.address);

  const testToken2 = await ethers.getContractFactory("FakeToken");

  let testtoken2 = await upgrades.deployProxy(testToken2,
    [gnosis, 6],
    { initializer: 'initialize', kind: 'uups' }
  );

  console.log("Test Token 2 (6 decimals) deployed to:", testtoken2.address);

  // Deepfi Token
  const DeepfiToken = await ethers.getContractFactory("DeepfiToken");

  let deepfiToken = await upgrades.deployProxy(DeepfiToken,
    [gnosis],
    { initializer: 'initialize', kind: 'uups' }
  );
  console.log("Deepfi Token deployed to:", deepfiToken.address);


  // Liquidity Handler
  const Handler = await ethers.getContractFactory("LiquidityHandler");

  let handler = await upgrades.deployProxy(Handler,
    // admin
    [gnosis],
    { initializer: 'initialize', kind: 'uups' }
  );

  console.log("Handler deployed to:", handler.address);

  // MLP Vault
  const MLPVault = await ethers.getContractFactory("D_Vault_SingleReward");

  let mlpVault = await upgrades.deployProxy(MLPVault,
    //vault name, staking token, reward token, admin, handler
    ["MLP", testtoken1.address, deepfiToken.address, gnosis, handler.address],
    { initializer: 'initialize', kind: 'uups' }
  );

  console.log("MLP Vault deployed to:", mlpVault.address);

  // MLP Adapter
  const MLPAdapter = await ethers.getContractFactory("MlpAdapter");

  let mlpAdapter = await upgrades.deployProxy(MLPAdapter,
    // treasury / handler / staking token / admin
    [gnosis, handler.address, testtoken1.address, gnosis],
    { initializer: 'initialize', kind: 'uups' }
  );
  console.log("MLP Adapter deployed to:", mlpAdapter.address);

  // EQZ Vault
  const EQZVault = await ethers.getContractFactory("D_Vault_SingleReward");

  let eqzVault = await upgrades.deployProxy(EQZVault,
    //vault name, staking token, reward token, admin, handler, trusted forwarder
    ["EQZ", testtoken2.address, deepfiToken.address, gnosis, handler.address],
    { initializer: 'initialize', kind: 'uups' }
  );
  console.log("EQZ Vault deployed to:", eqzVault.address);

  // EQZ Adapter
  const EQZAdapter = await ethers.getContractFactory("EqzAdapter");

  let eqzAdapter = await upgrades.deployProxy(EQZAdapter,
    // treasury , handler , staking token, admin, gauge (EQZ contract) address
    [gnosis, handler.address, testtoken2.address, gnosis, "0x48afe4b50aadbc09d0bceb796d9e956ea90f15b4"],
    { initializer: 'initialize', kind: 'uups' }
  );
  console.log("EQZ Adapter deployed to:", eqzAdapter.address);

  // const adapterId = await handler.getLastAdapterIndex();
  const adapterId = 1;
  await handler.setPoolToAdapterId(mlpVault.address, adapterId);
  await handler.setAdapter(adapterId, "Mlp Strategy", 0, mlpAdapter.address, true);
  // await deepfiToken.transfer(mlpVault.address, ethers.utils.parseEther("1000000"))


  const adapterId2 = 2;
  await handler.setPoolToAdapterId(eqzVault.address, adapterId2);
  await handler.setAdapter(adapterId2, "Eqz Strategy", 0, eqzAdapter.address, true);
  // await deepfiToken.transfer(eqzVault.address, ethers.utils.parseEther("1000000"))
}

deploy_testnet()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

export default deploy_testnet;
//npx hardhat run scripts/deploy/deploy_testnet.ts --network fantom_testnet
//npx hardhat verify 0xb647c6fe9d2a6e7013c7e0924b71fa7926b2a0a3 --network polygon