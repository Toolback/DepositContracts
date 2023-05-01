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

//v1
//0x5e689d7fb26ffc4bd615c98c8517a18ef1f5e68d
//0x5E689D7fB26FfC4BD615c98C8517A18ef1f5e68d
// approval for staking lp(vAMM) is made to this contract
interface IGauge {
    function rewards() external returns (address[] memory);
    function tokenIds(address tokenAddress) external returns (uint);
    function getReward() external;
    function earned(address token, address account) external view returns (uint);
    function depositAll(uint tokenId) external;
    function deposit(uint amount) external;
    function withdrawAll() external;
    function withdraw(uint amount) external;
    function withdrawToken(uint amount, uint tokenId) external;
}

// V2 vAMM USDC / WFTM 0x48afe4b50aadbc09d0bceb796d9e956ea90f15b4
interface IPair {
        /// @dev claim accumulated but unclaimed fees (viewable via claimable0 and claimable1)
        function claimFees() external returns (uint claimed0, uint claimed1);
        function transfer(address dst, uint amount) external returns (bool);

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
    address public treasury;

    address public eqzGauge_address;
    uint256 public gauge_tokenId;


    // bool public compoundRewardStatus;

    event removeToken(address indexed user, address indexed token, uint256 amount);
    event newTreasury(address new_treasury);
    event newLiquidityHandler(address new_handler);


    // modifier compoundReward() {

    //     _;
    // }

    function initialize(
        address _treasury,
        address _handlerAddress,
        address _stacking_token,
        address _multiSigWallet,
        address _eqzGauge_address
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
        stacking_token = _stacking_token; // ex : vAMM-USDC/WFTM 
        eqzGauge_address = _eqzGauge_address; // 0x5E689D7fB26FfC4BD615c98C8517A18ef1f5e68d;
  
        // gauge_tokenId = IGauge(_eqzGauge_address).tokenIds(_stacking_token);
        // IERC20Upgradeable(_stacking_token).approve(_eqzGauge_address, type(uint).max);
        
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

    function getEqzTokenId() public returns (uint){
        IGauge gauge = IGauge(eqzGauge_address);
        return gauge.tokenIds(stacking_token);
    }

    // /**
    //  * @notice /!\ WIP frontend metrics display 
    //  */
    // function getAdapterAmount() external returns (uint256[] memory) 
    // {
    //     uint256[] memory amounts = new uint256[](4);
    //     amounts[0] = address(this).balance;
    //     amounts[1] = IERC20Upgradeable(stacking_token).balanceOf(address(this));
    //     // amounts[2] = esMMY.balanceOf(address(this));
    //     // amounts[3] = esMMY.stakedBalance(address(this));
    //     return amounts;
    // }

    /* ========== ADMIN CONFIGURATION ========== */

    /**
     * @notice  function for transfer reward base token (ftm) to protocol treasury
     * @param _amount amount of the token being removed
     */
    function transferAdapterFTM(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        payable(treasury).transfer(_amount);
    }

    /**
     * @notice  admin function for removing blocked funds from contract
     * @param _address address of the token being removed
     * @param _to address of the recipient
     * @param _amount amount of the token being removed
     */
    function removeTokenByAddress(address _address, address _to, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        IERC20Upgradeable(_address).safeTransfer(_to, _amount);
        emit removeToken(_to, _address, _amount);
    }

    /* ------------------------------ Total Rewards ------------------------------ */

    // /**
    //  * @notice  manual Reward Compound for optimal rate
    //  */
    // function manualCompound() external {
    //     return;
    // }

    /**
     * @notice  function for claiming staking rewards on equalizer
     */
    function claimReward() external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IGauge gauge = IGauge(eqzGauge_address);
        // gauge.getReward(address(this), gauge.rewards());
        gauge.getReward();
    }

    /* ------------------------------ MLP Vault (vMLP) ------------------------------ */
    
    function depositMLPVault(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // IVester vester = IVester(MLPVester_address);
        // vester.deposit(_amount);
    }


    /* -------------------------------------------------------------------------- */

  function setSlippage(uint64 _newSlippage) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        return;
    }

    function setCompoundRewardStatus(bool _status) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // compoundRewardStatus = _status;
    }

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

    function setNewGaugeTokenId() external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        gauge_tokenId = IGauge(eqzGauge_address).tokenIds(stacking_token);
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