// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/Mummy.Finance/IRewardRouterV2.sol";
import "@openzeppelin/contracts/utils/Address.sol";


import "hardhat/console.sol";

contract MlpAdapter is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant HANDLER_ROLE = keccak256("HANDLER_ROLE");
    
    //flag for upgrades availability
    bool public upgradeStatus;

    address public liquidity_handler;
    address public stacking_token;
    address public reward_token;
    address public treasury;
    address public rewardRouter_address;

    uint256 public balance;


    modifier compoundReward() {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouter_address);
        rewardRouter.handleRewards(true, true, true, true, true, true, true);
        // rewardRouter.compound();

        _;
    }

    function initialize(
        address _handlerAddress,
        address _staking_token,
        address _reward_token,
        address _multiSigWallet,
        address _reward_router_address
        // address _exchangeAddress
    ) initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // require(isContract(_handlerAddress), "MLP Adapter : Handler Not contract");
        // require(isContract(_staking_token), "MLP Adapter : Staking Token Not contract");
        // require(isContract(_reward_token), "MLP Adapter : Reward Token Not contract");
        // // require(isContract(_multiSigWallet), "MLP Adapter : MultiSig Not contract");
        // require(isContract(_reward_router_address), "MLP Adapter : Reward Router Not contract");

        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(UPGRADER_ROLE, _multiSigWallet);
        _grantRole(HANDLER_ROLE, _handlerAddress);

        liquidity_handler = _handlerAddress;
        stacking_token = _staking_token;
        reward_token = _reward_token;
        rewardRouter_address = _reward_router_address;

    }



    function claimReward() internal
    {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouter_address);
        // claim reward from mummy
        rewardRouter.handleRewards(true, false, true, false, false, true, true);
        // transfer reward to treasu
        // IERC20Upgradeable(reward_token).safeTransfer(treasury, type(uint256).max);
    }

    function deposit(address _token, uint256 _amount) external compoundReward onlyRole(HANDLER_ROLE)
    {
        return;
    }

    function withdraw(address _user, address _token, uint256 _amount) external compoundReward onlyRole(HANDLER_ROLE)
    {
        IERC20Upgradeable(_token).safeTransfer(_user, _amount);
    }

    function getAdapterAmount() external compoundReward returns (uint256) 
    {
        // IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouter_address);
        // return rewardRouter.balanceOf(address(this));
        uint256 bal = IERC20Upgradeable(stacking_token).balanceOf(address(this));
        return (address(this).balance);
    }


    function setSlippage(uint64 _newSlippage) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        return;
    }

    function setWallet(address _newWallet) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        treasury = _newWallet;
    }

    function setRewardRouterAddress(address _address) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        rewardRouter_address = _address;
    }

    function claimAdapterReward() external compoundReward 
    {
        claimReward();
    }
    /**
     * @dev admin function for removing funds from contract
     * @param _address address of the token being removed
     * @param _amount amount of the token being removed
     */
    function removeTokenByAddress(address _address, address _to, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        IERC20Upgradeable(_address).safeTransfer(_to, _amount);
    }

    function changeUpgradeStatus(bool _status) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        upgradeStatus = _status;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE)
    {
        require(upgradeStatus, "Handler: Upgrade not allowed");
        upgradeStatus = false;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {
        balance+=msg.value;
    }

    // Fallback function is called when msg.data is not empty
    fallback() external payable {
        balance+=msg.value;
    }

}