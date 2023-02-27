// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IAdapter.sol";


import "hardhat/console.sol";

contract MlpAdapter is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant HANDLER_ROLE = keccak256("HANDLER_ROLE");
    
    //flag for upgrades availability
    bool public upgradeStatus;

    address public liquidity_handler;
    address public mlp_address;
    address public reward_token;
    address public treasury;

    function initialize(
        address _handlerAddress,
        address _mlp_address,
        address _reward_token,
        address _multiSigWallet
        // address _exchangeAddress
    ) initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // require(_multiSigWallet.isContract(), "Handler: Not contract");
        // require(_exchangeAddress.isContract(), "Handler: Not contract");
        // exchangeAddress = _exchangeAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(UPGRADER_ROLE, _multiSigWallet);
        _grantRole(HANDLER_ROLE, _handlerAddress);

        liquidity_handler = _handlerAddress;
        mlp_address = _mlp_address;
        reward_token = _reward_token;

    }

    function claimReward() internal
    {
        // claim reward from mummy

        // transfer reward to treasu
        // IERC20Upgradeable(reward_token).safeTransfer(treasury, type(uint256).max);
    }

    function deposit(address _token, uint256 _amount) external onlyRole(HANDLER_ROLE)
    {
        claimReward();
    }

    function withdraw(address _user, address _token, uint256 _amount) external onlyRole(HANDLER_ROLE)
    {
        claimReward();
        IERC20Upgradeable(_token).safeTransfer(_user, _amount);
    }

    function getAdapterAmount() external view returns (uint256) 
    {

        //     uint256 amount = IERC20Upgradeable(mlp_address).balanceOf(address(this));
        //     return amount * 10 ** (18 - ERC20(liquidToken).decimals());
 
        return IERC20Upgradeable(mlp_address).balanceOf(address(this));
    }


    function setSlippage(uint64 _newSlippage) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        return;
    }

    function setWallet(address _newWallet) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        treasury = _newWallet;
    }

    function getReward() external 
    {
        claimReward();
    }
    /**
     * @dev admin function for removing funds from contract
     * @param _address address of the token being removed
     * @param _amount amount of the token being removed
     */
    function removeTokenByAddress(
        address _address,
        address _to,
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20Upgradeable(_address).safeTransfer(_to, _amount);
    }

    function changeUpgradeStatus(bool _status)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        upgradeStatus = _status;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {
        require(upgradeStatus, "Handler: Upgrade not allowed");
        upgradeStatus = false;
    }

}