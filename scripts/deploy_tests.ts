import { ethers, upgrades } from "hardhat"

async function deploy_tests(owner: any, stakingToken: any) {
	// Test Token (only for tests)
	const TestToken6 = await ethers.getContractFactory("FakeToken");

	let testToken6 = await upgrades.deployProxy(TestToken6,
		[owner.address, 6],
		{ initializer: 'initialize', kind: 'uups' }
	);



	// Test Token (only for tests)
	const TestToken18 = await ethers.getContractFactory("FakeToken");

	let testToken18 = await upgrades.deployProxy(TestToken18,
		[owner.address, 18],
		{ initializer: 'initialize', kind: 'uups' }
	);

	if (stakingToken == "testToken6")
		stakingToken = testToken6;
	else if (stakingToken === "testToken18")
		stakingToken = testToken18;

	// Deepfi Token
	const DeepfiToken = await ethers.getContractFactory("DeepfiToken");

	let deepfiToken = await upgrades.deployProxy(DeepfiToken,
		[owner.address],
		{ initializer: 'initialize', kind: 'uups' }
	);


	// Liquidity Handler
	const Handler = await ethers.getContractFactory("LiquidityHandler");

	let handler = await upgrades.deployProxy(Handler,
		// admin, deepfi token
		[owner.address],
		{ initializer: 'initialize', kind: 'uups' }
	);


	// MLP Vault
	const MLPVault = await ethers.getContractFactory("D_Vault_SingleReward");

	let mlpVault = await upgrades.deployProxy(MLPVault,
		//staking token, reward token, admin, handler, trusted forwarder
		["MLP", stakingToken.address, deepfiToken.address, owner.address, handler.address],
		{ initializer: 'initialize', kind: 'uups' }
	);

	// MLP Adapter
	const MLPAdapter = await ethers.getContractFactory("MlpAdapter");

	let mlp_adapter = await upgrades.deployProxy(MLPAdapter,
		// reward_router address (mummy contract)/ handler / staking token / reward token / admin
		[handler.address, stakingToken.address, deepfiToken.address, owner.address, "0x7b9e962dd8AeD0Db9A1D8a2D7A962ad8b871Ce4F"],
		{ initializer: 'initialize', kind: 'uups' }
	);

	// const adapterId = await handler.getLastAdapterIndex();
	const adapterId = 1;
	await handler.connect(owner).setPoolToAdapterId(mlpVault.address, adapterId);
	await handler.connect(owner).setAdapter(adapterId, "Mlp Strategy", 0, mlp_adapter.address, true);
	// await handler.grantRole(handler.DEFAULT_ADMIN_ROLE(), pool_usdc.address);
	await deepfiToken.connect(owner).transfer(mlpVault.address, ethers.utils.parseEther("1000000"))

	return ({
		testToken6,
		testToken18,
		deepfiToken,
		handler,
		mlpVault,
		mlp_adapter
	})

}


export default deploy_tests;
