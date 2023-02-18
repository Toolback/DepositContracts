# Important 

// In contract Address from openzepellin l.185 delegatecall commented

# WIP


# DefiLP Contract
[WIP]
The DefiLP contract is a decentralized finance (DeFi) liquidity pool contract that allows users to deposit and earn returns on their deposited assets. It is designed to be upgradeable, allowing for the implementation to be modified and improved over time.

## Features
The DefiLP contract has the following features:

Support for ERC20 tokens: Users can deposit ERC20 tokens into the liquidity pool and earn returns on their deposited assets.

Pausable: admins can pause and resume the contract, allowing for maintenance or emergency situations.

Role-based access control: The contract has roles such as PAUSER_ROLE, MINTER_ROLE, and UPGRADER_ROLE that can be assigned and revoked by an authorized party. These roles give parties the ability to perform certain actions on the contract.

Upgradeable: The contract can be upgraded by creating a new contract implementation and replacing the current one.

## Functions
The D_Pool_SingleReward contract has the following functions:

initialize: This function is called when the contract is deployed and is used to set up the contract, including setting the annual interest rate, update time limit, and liquidity handler address.

deposit: This function allows users to deposit ERC20 tokens into the liquidity pool.

withdraw: This function allows users to withdraw their deposited assets.

claimReward: claim all rewards earned by staking.

getRewardBalance: retrieve user available gains balance.

setRewardsDuration: allow admins to increase duration of an ongoing reward, or set a new one

notifyRewardAmount: allow admins to increase amount of reward token, or set a new reward

setLiquidityHandler: This function allows admins to set the contract responsible for distributing money between the pool and the wallet.

setTrustedForwarder: This function allows admins to set the trusted forwarder address, which is used to perform certain actions on behalf of the contract.

depositTokenStatus: This function allows admins to enable or disable the ability for users to deposit a particular ERC20 token.


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