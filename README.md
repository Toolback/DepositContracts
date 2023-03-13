# Important 

// In contract Address from openzepellin l.185 delegatecall commented

# Contracts Address
## Fantom Testnet
➜  DepositContracts git:(main) ✗ npx hardhat run scripts/deploy_testnet.ts --network fantom_testnet
Test Token deployed to: 0x87a64cDe9ee4141c086eE151553A5b1E2056F2a7
Deepfi Token deployed to: 0x7b76dc056AD4Cc014a392Dcc4aac424E7506d251
Handler deployed to: 0x47c03f1a44Ab370994419cA38Ac05E70DEC10578
MLP Vault deployed to: 0xc3fa3096A0853Ab1199eA504ad2C167a0eB92680
MLP Adapter deployed to: 0xC3CCE338bC613F4c7aB05fd7730da020DA54D9BD

## Fantom Mainnet

# WIP
[] -> fix mintInterval of deepfi token (actual testing 365 days)
[~] -> Set claim first adapter
[~] -> run tests
[~] -> set withdraw fees on pools

<img src="./VaultSchema.png" alt="Vault Schema"/>

# D_Vault_SingleReward Contract
[WIP]
The D_Vault_SingleReward contract is a decentralized finance (DeFi) liquidity pool contract that allows users to deposit and earn returns on their deposited assets. It is designed to be upgradeable, allowing for the implementation to be modified and improved over time.

## Features
The D_Vault_SingleReward contract has the following features:

Support for ERC20 tokens: Users can deposit ERC20 tokens into the liquidity pool and earn returns on their deposited assets.

Pausable: admins can pause and resume the contract, allowing for maintenance or emergency situations.

Role-based access control: The contract has roles such as PAUSER_ROLE, MINTER_ROLE, and UPGRADER_ROLE that can be assigned and revoked by an authorized party. These roles give parties the ability to perform certain actions on the contract.

Upgradeable: The contract can be upgraded by creating a new contract implementation and replacing the current one.

## Functions
The D_Vault_SingleReward contract has the following functions:

initialize: This function is called when the contract is deployed and is used to set up the contract, including setting the annual interest rate, update time limit, and liquidity handler address.

deposit: This function allows users to deposit ERC20 tokens into the liquidity pool.

withdraw: This function allows users to withdraw their deposited assets.

claimReward: claim all rewards earned by staking.

getRewardBalance: retrieve user available gains balance.

setRewardsDuration: allow admins to increase duration of an ongoing reward, or set a new one

notifyRewardAmount: allow admins to increase amount of reward token, or set a new reward

setLiquidityHandler: This function allows admins to set the contract responsible for distributing money between the pool and the strategy.

setTrustedForwarder: This function allows admins to set the trusted forwarder address, which is used to perform certain actions on behalf of the contract.


# LiquidityHandler Contract
[WIP]
The LiquidityHandler contract is a contract that handles liquidity, allowing users to deposit and withdraw assets. It is designed to be upgradeable, allowing for the implementation to be modified and improved over time.

## Features
The LiquidityHandler contract has the following features:

Liquidity Hub : centralizes and dispatches funds to the different strategies of the protocol, also handles withdrawals

Pausable: admins can pause and resume the contract, allowing for maintenance or emergency situations.

Role-based access control: The contract has a UPGRADER_ROLE that can be assigned and revoked by admins. This role gives parties the ability to perform certain actions on the contract.

Upgradeable: The contract can be upgraded by creating a new contract implementation and replacing the current one.

## Functions
The LiquidityHandler contract has the following functions:

initialize: This function is called when the contract is deployed and is used to set up the contract, including setting the multi-sig wallet address and protocol governance token address.

deposit: This function allows users to deposit assets into the platform.

withdraw: This function allows users to withdraw their deposited assets.

addPool: This function allows admins to add a new Pool to the list of deployed pools.

removePool: This function allows admins to remove a Pool from the list of deployed pools.