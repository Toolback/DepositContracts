// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ILiquidityHandler
{
    function withdraw(address _user, address _token, uint256 _amount) external;
    function claimUserReward(address to, uint256 amount) external;
    function grantRole(bytes32 role, address account) external;

}