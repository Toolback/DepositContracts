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

interface IesMMY{
    function stakedBalance(address _account) external returns(uint256);
    function balanceOf(address _account) external returns(uint256);
}

interface IRewardRouterV2{
    function handleRewards(
        bool _shouldClaimGmx, 
        bool _shouldStakeGmx, 
        bool _shouldClaimEsGmx, 
        bool _shouldStakeEsGmx, 
        bool _shouldStakeMultiplierPoints, 
        bool _shouldClaimWeth, 
        bool _shouldConvertWethToEth
    ) external;
    function stakeEsGmx(uint256 _amount) external;
    function unstakeEsGmx(uint256 _amount) external;
    function signalTransfer(address _receiver) external;
}

interface IVester{
    function deposit(uint256 _amount) external;
    function withdraw() external;
}

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
    address public treasury;
    address public rewardRouter_address;
    address public esMMY_address;
    address public MLPVester_address;
    address public MMYVester_address;

    bool public compoundRewardStatus;

    event removeToken(address indexed user, address indexed token, uint256 amount);
    event transferMummyFinanceAccount(address _newAddress);
    event newTreasury(address new_treasury);
    event newLiquidityHandler(address new_handler);


    modifier compoundReward() {
        if (compoundRewardStatus)
        {
            IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouter_address);
            rewardRouter.handleRewards(true, true, true, true, true, true, true);
        }

        _;
    }

    function initialize(
        address _treasury,
        address _handlerAddress,
        address _staking_token,
        address _multiSigWallet
    ) initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        require(_handlerAddress.isContract(), "MLP Adapter : Handler Not contract");
        // require(isContract(_multiSigWallet), "MLP Adapter : MultiSig Not contract");

        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(UPGRADER_ROLE, _multiSigWallet);
        _grantRole(HANDLER_ROLE, _handlerAddress);

        treasury = _treasury;
        liquidity_handler = _handlerAddress;
        stacking_token = _staking_token;
        rewardRouter_address = 0x7b9e962dd8AeD0Db9A1D8a2D7A962ad8b871Ce4F;
        esMMY_address = 0xe41c6c006De9147FC4c84b20cDFBFC679667343F;
        MLPVester_address = 0x2A3E489F713ab6F652aF930555b5bb3422711ac1;
        MMYVester_address = 0xa1a65D3639A1EFbFB18C82003330a4b1FB620C5a; 
        compoundRewardStatus = true;

    }

    /**
     * @notice  function called by handler when vault deposit
     * @dev only used for compound reward / adapter patern
     * @param _token address of the token being removed
     * @param _amount amount of the token being removed
     */
    function deposit(address _token, uint256 _amount) external compoundReward onlyRole(HANDLER_ROLE)
    {
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
    function withdraw(address _user, address _token, uint256 _full_amout, uint256 _deducted_amount, uint256 _fees) external compoundReward onlyRole(HANDLER_ROLE)
    {
        IERC20Upgradeable(_token).safeTransfer(_user, _deducted_amount);
        IERC20Upgradeable(_token).safeTransfer(treasury, _fees);
    }

    /**
     * @notice /!\ WIP frontend metrics display 
     */
    function getAdapterAmount() external returns (uint256[] memory) 
    {
        IesMMY esMMY = IesMMY(esMMY_address);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = address(this).balance;
        amounts[1] = IERC20Upgradeable(stacking_token).balanceOf(address(this));
        amounts[2] = esMMY.balanceOf(address(this));
        amounts[3] = esMMY.stakedBalance(address(this));
        return amounts;
    }

    /* ========== ADMIN CONFIGURATION ========== */

    /**
     * @notice  function for transfer rewards to protocol treasury
     * @param _amount amount of the token being removed
     */
    function transferAdapterRewards(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        payable(treasury).transfer(_amount);
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
     * @notice  manual Reward Compound for optimal rate
     */
    function manualCompound() external compoundReward {
        return;
    }

    /**
     * @notice  function for claiming pending esMMY and FTM
     */
    function claimReward() external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouter_address);
        rewardRouter.handleRewards(true, false, true, false, false, true, true);
    }

    /* ------------------------------ MLP Vault (vMLP) ------------------------------ */
    
    function depositMLPVault(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IVester vester = IVester(MLPVester_address);
        vester.deposit(_amount);
    }

    function withdrawMLPVault() external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IVester vester = IVester(MLPVester_address);
        vester.withdraw();
    }

    /* ------------------------------ MMY Vault (vMMY) ------------------------------ */
    
    function depositMMYVault(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IVester vester = IVester(MMYVester_address);
        vester.deposit(_amount);
    }

    function withdrawMMYVault() external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IVester vester = IVester(MMYVester_address);
        vester.withdraw();
    }

    /* ------------------------------ Escrowed MMY (esMMY) ------------------------------ */
    function stakeEsMMY(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouter_address);
        rewardRouter.stakeEsGmx(_amount);
    }

    function unstakeEsMMY(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouter_address);
        rewardRouter.unstakeEsGmx(_amount);
    }

    /* ------------------------------ Transfer Mummy Account ------------------------------ */
    function transferMummyFiAccount(address _newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouter_address);
        rewardRouter.signalTransfer(_newAddress);

        emit transferMummyFinanceAccount(_newAddress);
    }
    /* -------------------------------------------------------------------------- */

  function setSlippage(uint64 _newSlippage) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        return;
    }

    function setCompoundRewardStatus(bool _status) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        compoundRewardStatus = _status;
    }

    function setNewTreasury(address _newWallet) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        treasury = _newWallet;
        emit newTreasury(_newWallet);
    }

    function setLiquidityHandler(address _newHandler) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_newHandler.isContract(), "MLP Adapter : Handler Address Not contract");
        _revokeRole(HANDLER_ROLE, liquidity_handler);
        _grantRole(HANDLER_ROLE, _newHandler);
        liquidity_handler = _newHandler;
        emit newLiquidityHandler(_newHandler);
    }

    function setesMMYAddress(address _address) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_address.isContract(), "MLP Adapter : Address Not contract");
        esMMY_address = _address;
    }

    function setRewardRouterAddress(address _address) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_address.isContract(), "MLP Adapter : Address Not contract");
        rewardRouter_address = _address;
    }

    function setMLPVesterAddress(address _address) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_address.isContract(), "MLP Adapter : Address Not contract");
        MLPVester_address = _address;
    }

    function setMMYVesterAddress(address _address) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_address.isContract(), "MLP Adapter : Address Not contract");
        MMYVester_address = _address;
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