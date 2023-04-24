// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAdapter {
    function deposit(address _token, uint256 _amount) external;

    function withdraw(
        address _user, 
        address _token, 
        uint256 _full_amout, 
        uint256 _deducted_amount, 
        uint256 _fees
    ) external;

    function getAdapterAmount() external view returns (uint256[] memory);
    
    function setSlippage(uint64 _newSlippage) external;

    function setWallet(address _newWallet) external;

}