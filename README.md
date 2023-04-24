# Contracts Address
## Fantom Testnet
➜  DepositContracts git:(main) ✗ npx hardhat run scripts/deploy_testnet.ts --network fantom_testnet
Test Token 1 (18 decimals) deployed to: 0x410949Ed1ed5d8ac7A8f024b200da766C48217ed  
Test Token 2 (6 decimals) deployed to: 0x41BEf4AfcAcc42D7906eed8bd87147F37F68EF14   
Deepfi Token deployed to: 0xc05ce0bb5e0F7D14a4003FBeBBB909C9DEe988f0
Handler deployed to: 0xc14437ff07aEF48CE97410171A31C13956fa9047
MLP Vault deployed to: 0xE1F390e00Da8E5Acb83De3b3a9Ab829be5b49F4c
MLP Adapter deployed to: 0x4FEb39BF919fA7370c6257Abd518302B365EDdBe
EQZ Vault deployed to: 0x35d8F28808e1A6058032895843f9b50A892B2900
EQZ Adapter deployed to: 0xEa0Da285DEdE06e12cA6289A40fD70A787FF2859

## Fantom Mainnet

# WIP
[] -> fix mintInterval of deepfi token (actual testing 365 days)
[~] -> set withdraw fees on pools
[~] -> run tests

<img src="./VaultSchema.png" alt="Vault Schema"/>

# D_Vault_SingleReward Contract
[WIP]
The D_Vault_SingleReward contract is a decentralized finance (DeFi) vault contract that allows users to deposit and earn returns on their deposited assets. It is designed to be upgradeable, allowing for the implementation to be modified and improved over time.

## Features
The D_Vault_SingleReward contract has the following features:

Support for ERC20 tokens: Users can deposit ERC20 tokens into the vault and earn returns on their deposited assets.

Pausable: admins can pause and resume the contract, allowing for maintenance or emergency situations.

Role-based access control: The contract has roles such as PAUSER_ROLE, MINTER_ROLE, and UPGRADER_ROLE that can be assigned and revoked by an authorized party. These roles give parties the ability to perform certain actions on the contract.

Upgradeable: The contract can be upgraded by creating a new contract implementation and replacing the current one.

## Functions
The D_Vault_SingleReward contract has the following functions:

initialize: This function is called when the contract is deployed and is used to set up the contract, including setting the annual interest rate, update time limit, and liquidity handler address.

deposit: This function allows users to deposit ERC20 tokens into the vault.

withdraw: This function allows users to withdraw their deposited assets.

claimReward: claim all user rewards earned by staking.

getRewardBalance: retrieve user available gains balance.

getStakeBalance: retrieve user deposited balance.

getTotalUserEarned : retrieve user claimed asset balance.

setRewardsDuration: allow admins to increase duration of an ongoing reward, or set a new one

notifyRewardAmount: allow admins to increase amount of reward token, or set a new reward

setLiquidityHandler: This function allows admins to set the contract responsible for distributing money between the pool and the strategy.


# LiquidityHandler Contract
[WIP]
The LiquidityHandler contract is a contract that handles liquidity from vaults to adapters. It is designed to be upgradeable, allowing for the implementation to be modified and improved over time.

## Features
The LiquidityHandler contract has the following features:

Liquidity Hub : centralizes and dispatches funds to the different strategies of the protocol, also handles deposit & withdrawals

Pausable: admins can pause and resume the contract, allowing for maintenance or emergency situations.

Role-based access control: The contract has a UPGRADER_ROLE that can be assigned and revoked by admins. This role gives parties the ability to perform certain actions on the contract.

Upgradeable: The contract can be upgraded by creating a new contract implementation and replacing the current one.

## Functions
The LiquidityHandler contract has the following functions:

initialize: This function is called when the contract is deployed and is used to set up the contract, including setting the multi-sig wallet address and protocol governance token address.

deposit: Called by Vault on user demand. This function allows users to deposit assets into the protocol.

withdraw: Called by Vault on user demand. This function allows users to withdraw their deposited assets.

addPool: This function allows admins to add a new Pool to the list of deployed pools.

removePool: This function allows admins to remove a Pool from the list of deployed pools.