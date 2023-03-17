import { ethers, upgrades } from "hardhat"

async function deploy_testnet() {
  const gnosis = "0x25b3d91e2cbAe2397749f2F9A5598366Df26fA49"; // privatekey
  //   const gnosis = "0xe76c64A113da0fF58D31C2b7A6F7168d842E5912"; //mnemo

  // Test Token (only for testnet)
  const testToken = await ethers.getContractFactory("FakeToken");

  let testtoken = await upgrades.deployProxy(testToken,
    [gnosis],
    { initializer: 'initialize', kind: 'uups' }
  );

  console.log("Test Token deployed to:", testtoken.address);

  // Deepfi Token
  const DeepfiToken = await ethers.getContractFactory("DeepfiToken");

  let erc20 = await upgrades.deployProxy(DeepfiToken,
    [gnosis],
    { initializer: 'initialize', kind: 'uups' }
  );
  console.log("Deepfi Token deployed to:", erc20.address);


  // Liquidity Handler
  const Handler = await ethers.getContractFactory("LiquidityHandler");

  let handler = await upgrades.deployProxy(Handler,
    // admin, deepfi token
    [gnosis, erc20.address],
    { initializer: 'initialize', kind: 'uups' }
  );

  console.log("Handler deployed to:", handler.address);

  // MLP Vault
  const MLPVault = await ethers.getContractFactory("D_Vault_SingleReward");

  let mlpVault = await upgrades.deployProxy(MLPVault,
    //staking token, reward token, admin, handler, trusted forwarder
    ["MLP", testtoken.address, erc20.address, gnosis, handler.address],
    { initializer: 'initialize', kind: 'uups' }
  );

  console.log("MLP Vault deployed to:", mlpVault.address);

  // MLP Adapter
  const MLPAdapter = await ethers.getContractFactory("MlpAdapter");

  let mlpAdapter = await upgrades.deployProxy(MLPAdapter,
    // handler / staking token admin
    [handler.address, testtoken.address, gnosis],
    { initializer: 'initialize', kind: 'uups' }
  );

  console.log("MLP Adapter deployed to:", mlpAdapter.address);

  // const adapterId = await handler.getLastAdapterIndex();
  const adapterId = 1;
  await handler.setPoolToAdapterId(mlpVault.address, adapterId);
  await handler.setAdapter(adapterId, "Mlp Strategy", 0, mlpAdapter.address, true);
  // await handler.grantRole(handler.DEFAULT_ADMIN_ROLE(), pool_usdc.address);
  await erc20.transfer(mlpVault.address, ethers.utils.parseEther("1000000"))

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