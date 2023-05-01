import { ethers, upgrades } from "hardhat"

async function deploy_hardhat(owner: any, stakingToken: any, ) {
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
		// admin
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
		// reward_router address (mummy contract)/ handler / staking token / admin
		[owner.address, handler.address, stakingToken.address, owner.address],
		{ initializer: 'initialize', kind: 'uups' }
	);

	// EQZ Vault
	const Eqz_USDC_WFTM_vault = await ethers.getContractFactory("D_Vault_SingleReward");

	let eqz_USDC_WFTM_vault = await upgrades.deployProxy(Eqz_USDC_WFTM_vault,
		//staking token, reward token, admin, handler, trusted forwarder
		["EQZ", stakingToken.address, deepfiToken.address, owner.address, handler.address],
		{ initializer: 'initialize', kind: 'uups' }
	);

	// EQZ Adapter
	const EQZAdapter = await ethers.getContractFactory("EqzAdapter");

	let eqz_USDC_WFTM_adapter = await upgrades.deployProxy(EQZAdapter,
		// reward_router address (mummy contract)/ handler / staking token / admin / EQZ Gauge
		[owner.address, handler.address, stakingToken.address, owner.address],
		{ initializer: 'initialize', kind: 'uups' }
	);

	// const adapterId = await handler.getLastAdapterIndex();
	const adapterId = 1;
	await handler.connect(owner).setPoolToAdapterId(mlpVault.address, adapterId);
	await handler.connect(owner).setAdapter(adapterId, "Mlp Strategy", 0, mlp_adapter.address, true);
	// await handler.grantRole(handler.DEFAULT_ADMIN_ROLE(), pool_usdc.address);

	const adapterId2 = 2;
	await handler.connect(owner).setPoolToAdapterId(eqz_USDC_WFTM_vault.address, adapterId2);
	await handler.connect(owner).setAdapter(adapterId2, "Eqz - USDC/WFTM Strategy", 0, eqz_USDC_WFTM_adapter.address, true);
	// await handler.grantRole(handler.DEFAULT_ADMIN_ROLE(), pool_usdc.address);

	return ({
		testToken6,
		testToken18,
		deepfiToken,
		handler,
		mlpVault,
		mlp_adapter,
		eqz_USDC_WFTM_vault,
		eqz_USDC_WFTM_adapter
	})

}


export default deploy_hardhat;
