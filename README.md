# Contracts Address
## Fantom Testnet
➜  DepositContracts git:(main) ✗ npx hardhat run scripts/deploy_testnet.ts --network fantom_testnet
Test Token 1 (18 decimals) deployed to: 0x97d8a4c69499c944c4EcFBb48fE563E53749b823
Test Token 2 (6 decimals) deployed to: 0xC3c263D1B2F9a1b7de8231000552011F4102FFCE
Deepfi Token deployed to: 0x89778246158Da1bf386E0fa1bb661cE5465B08F4
Handler deployed to: 0x0961E3c4A37415364792Ddf0F1B5809350ce35BF
MLP Vault deployed to: 0xC865155957093435F712BEcB25A62c3245a16199
MLP Adapter deployed to: 0xc4796A2dB89a04dEFFc12509C15561BC145F86B6
EQZ Vault deployed to: 0x61D445dD4B07C1C0DEeA24EcaD7e8C8d1BB8dBC4
EQZ Adapter deployed to: 0x0a7045214fdc8082B6f6755B528dC14Bf7253767

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