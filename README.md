# Important 

// In contract Address from openzepellin l.185 delegatecall commented


# DefiLP Contract
The DefiLP contract is a decentralized finance (DeFi) liquidity pool contract that allows users to deposit and earn returns on their deposited assets. It is designed to be upgradeable, allowing for the implementation to be modified and improved over time.

## Features
The DefiLP contract has the following features:

Support for ERC20 tokens: Users can deposit ERC20 tokens into the liquidity pool and earn returns on their deposited assets.

Pausable: An authorized party can pause and resume the contract, allowing for maintenance or emergency situations.

Role-based access control: The contract has roles such as PAUSER_ROLE, MINTER_ROLE, and UPGRADER_ROLE that can be assigned and revoked by an authorized party. These roles give parties the ability to perform certain actions on the contract.

Upgradeable: The contract can be upgraded by creating a new contract implementation and replacing the current one.

## Functions
The DefiLP contract has the following functions:

initialize: This function is called when the contract is deployed and is used to set up the contract, including setting the annual interest rate, update time limit, and liquidity handler address.

deposit: This function allows users to deposit ERC20 tokens into the liquidity pool.

withdraw: This function allows users to withdraw their deposited assets, including any earned returns.

setUpdateTimeLimit: This function allows an authorized party to set the minimum time between reward updates for users.

setLiquidityHandler: This function allows an authorized party to set the contract responsible for distributing money between the pool and the wallet.

setTrustedForwarder: This function allows an authorized party to set the trusted forwarder address, which is used to perform certain actions on behalf of the contract.

depositTokenStatus: This function allows an authorized party to enable or disable the ability for users to deposit a particular ERC20 token.

setAnnualInterest: This function allows an authorized party to set the annual interest rate for the liquidity pool.

# LiquidityHandler Contract
The LiquidityHandler contract is a contract that handles liquidity, allowing users to deposit and withdraw assets. It is designed to be upgradeable, allowing for the implementation to be modified and improved over time.

## Features
The LiquidityHandler contract has the following features:

Pausable: An authorized party can pause and resume the contract, allowing for maintenance or emergency situations.

Role-based access control: The contract has a UPGRADER_ROLE that can be assigned and revoked by an authorized party. This role gives parties the ability to perform certain actions on the contract.

Upgradeable: The contract can be upgraded by creating a new contract implementation and replacing the current one.

## Functions
The LiquidityHandler contract has the following functions:

initialize: This function is called when the contract is deployed and is used to set up the contract, including setting the multi-sig wallet address and protocol governance token address.

deposit: This function allows users to deposit assets into the platform.

withdraw: This function allows users to withdraw their deposited assets.

addIbToken: This function allows an authorized party to add a new ERC20 token to the list of deployed tokens.

removeIbToken: This function allows an authorized party to remove an ERC20 token from the list of deployed tokens.