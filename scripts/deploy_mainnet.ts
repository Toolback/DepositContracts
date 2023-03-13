import { ethers, upgrades } from "hardhat"

async function deployProtocol() {
      const gnosis = "0x25b3d91e2cbAe2397749f2F9A5598366Df26fA49";
      const mlpAddress = "";
      const rewardRouter_address = "0x7b9e962dd8AeD0Db9A1D8a2D7A962ad8b871Ce4F"
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
            [gnosis, erc20.address],
            { initializer: 'initialize', kind: 'uups' }
      );

      console.log("Handler deployed to:", handler.address);

      // MLP Vault
      const MLPVault = await ethers.getContractFactory("D_Vault_SingleReward");

      let mlpVault = await upgrades.deployProxy(MLPVault,
            [mlpAddress, erc20.address, gnosis, handler.address, gnosis],
            { initializer: 'initialize', kind: 'uups' }
      );

      console.log("MLP Vault deployed to:", mlpVault.address);

      // MLP Adapter
      const MLPAdapter = await ethers.getContractFactory("MlpAdapter");

      let mlpAdapter = await upgrades.deployProxy(MLPAdapter,
            [handler.address, mlpAddress, erc20.address, gnosis, rewardRouter_address],
            { initializer: 'initialize', kind: 'uups' }
      );

      console.log("MLP Adapter deployed to:", mlpAdapter.address);
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