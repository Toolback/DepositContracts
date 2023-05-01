// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IAdapter.sol";
import "@openzeppelin/contracts/utils/Address.sol";


import "hardhat/console.sol";

//v1 0x5e689d7fb26ffc4bd615c98c8517a18ef1f5e68d
//v2 0x48afe4b50aadbc09d0bceb796d9e956ea90f15b4
// approval for staking lp(vAMM) is made to this contract
interface IGauge {
    function tokenIds(address tokenAddress) external returns (uint);
    function getReward() external;
    function depositAll() external;
    function deposit(uint amount) external;
    function withdrawAll() external;
    function withdraw(uint amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract EqzAdapter is
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
    address public stacking_token; //  vAMM-USDC/WFTM  => 0x7547d05dFf1DA6B4A2eBB3f0833aFE3C62ABD9a1
    address public equal_token;
    address public treasury;

    address public eqzGauge_address;

    // bool public compoundRewardStatus;

    event removeToken(address indexed user, address indexed token, uint256 amount);
    event newTreasury(address new_treasury);
    event newLiquidityHandler(address new_handler);

    function initialize(
        address _treasury,
        address _handlerAddress,
        address _stacking_token,
        address _multiSigWallet
    ) initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        require(_handlerAddress.isContract(), "EQZ Adapter : Handler Not contract");
        // require(isContract(_multiSigWallet), "EQZ Adapter : MultiSig Not contract");

        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(UPGRADER_ROLE, _multiSigWallet);
        _grantRole(HANDLER_ROLE, _handlerAddress);
        
        treasury = _treasury;
        liquidity_handler = _handlerAddress;
        stacking_token = _stacking_token; // vAMM-USDC/WFTM 
        eqzGauge_address = 0x48afe4b50AADbC09D0bCEb796D9E956eA90F15b4; //vAMM-USDC/WFTM gauge contract;
        equal_token = 0x3Fd3A0c85B70754eFc07aC9Ac0cbBDCe664865A6;
        // IERC20Upgradeable(_stacking_token).approve(eqzGauge_address, type(uint).max);
    }

    /**
     * @notice  function called by handler when vault deposit
     * @dev only used for compound reward / adapter pattern
     * @param _token address of the token being removed
     * @param _amount amount of the token being removed
     */
    function deposit(address _token, uint256 _amount) external onlyRole(HANDLER_ROLE)
    {
        IGauge gauge = IGauge(eqzGauge_address);
        IERC20Upgradeable(stacking_token).approve(eqzGauge_address, _amount);
        gauge.deposit(_amount);
        return;
    }

    /**
     * @notice  function called by handler when vault withdraw
     * @param _user address of the recipient
     * @param _token address of the token being removed
     * @param _full_amout amount of the token being removed
     * @param _deducted_amount amount of the token - fees
     * @param _fees fees amount (0.1%)
     */
    function withdraw(address _user, address _token, uint256 _full_amout, uint256 _deducted_amount, uint256 _fees) external onlyRole(HANDLER_ROLE)
    {
        IGauge gauge = IGauge(eqzGauge_address);
        gauge.withdraw(_full_amout);
        IERC20Upgradeable(_token).safeTransfer(_user, _deducted_amount);
        IERC20Upgradeable(_token).safeTransfer(treasury, _fees);
    }

    // /**
    //  * @notice /!\ WIP frontend metrics display 
    //  */
    function getAdapterAmount() external view returns (uint256[] memory) 
    {
        IGauge gauge = IGauge(eqzGauge_address);

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = address(this).balance;
        amounts[1] = IERC20Upgradeable(stacking_token).balanceOf(address(this));
        amounts[2] = gauge.balanceOf(address(this));
        amounts[3] = IERC20Upgradeable(equal_token).balanceOf(address(this));
        return amounts;
    }

    /* ========== ADMIN CONFIGURATION ========== */

    /**
     * @notice  function for transfer base token (ftm) to protocol treasury
     * @param _amount amount of the token being removed
     */
    function transferAdapterRewards(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 rewardBal = IERC20Upgradeable(equal_token).balanceOf(address(this));
        payable(treasury).transfer(_amount);
        IERC20Upgradeable(equal_token).safeTransfer(treasury, rewardBal);
    }

    // /**
    //  * @notice  admin function for removing blocked funds from contract
    //  * @param _address address of the token being removed
    //  * @param _to address of the recipient
    //  * @param _amount amount of the token being removed
    //  */
    // function removeTokenByAddress(address _address, address _to, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) 
    // {
    //     IERC20Upgradeable(_address).safeTransfer(_to, _amount);
    //     emit removeToken(_to, _address, _amount);
    // }

    /* ------------------------------ Total Rewards ------------------------------ */

    /**
     * @notice  function for claiming staking rewards on equalizer
     */
    function claimReward() external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IGauge gauge = IGauge(eqzGauge_address);
        gauge.getReward();
    }

    /* -------------------------------------------------------------------------- */

  function setSlippage(uint64 _newSlippage) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        return;
    }

    // function setCompoundRewardStatus(bool _status) external onlyRole(DEFAULT_ADMIN_ROLE)
    // {
    //     // compoundRewardStatus = _status;
    // }

    function setNewTreasury(address _newWallet) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        treasury = _newWallet;
        emit newTreasury(_newWallet);
    }

    function setLiquidityHandler(address _newHandler) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_newHandler.isContract(), "EQZ Adapter : Handler Not contract");
        _revokeRole(HANDLER_ROLE, liquidity_handler);
        _grantRole(HANDLER_ROLE, _newHandler);
        liquidity_handler = _newHandler;
        emit newLiquidityHandler(_newHandler);
    }

    function setNewGaugeAddress(address _newAddress) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_newAddress.isContract(), "EQZ Adapter : Gauge Address Not contract");
        eqzGauge_address = _newAddress;
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
    }

    // Fallback function is called when msg.data is not empty
    fallback() external payable {
    }

}