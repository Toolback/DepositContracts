// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

// import "./interfaces/IIbDeepFy.sol";
// import "../interfaces/IExchange.sol";
import "hardhat/console.sol";

contract LiquidityHandler is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using Address for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    //flag for upgrades availability
    bool public upgradeStatus;

    // Protocol Governance Token used for rewarding user staking
    address public defiToken;

    // list of deployed IbTokens
    EnumerableSetUpgradeable.AddressSet private deployedTokens;

    // struct Withdrawal {
    //     // address of user that did withdrawal
    //     address user;
    //     // address of token that user chose to receive
    //     address token;
    //     // amount to recieve
    //     uint256 amount;
    //     // withdrawal time
    //     uint256 time;
    // }

//     /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() initializer {}


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }


    function initialize(
        address _multiSigWallet,
        address _defiToken
        // address _exchangeAddress
    ) initializer public {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // require(_multiSigWallet.isContract(), "Handler: Not contract");
        // require(_exchangeAddress.isContract(), "Handler: Not contract");
        // exchangeAddress = _exchangeAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(UPGRADER_ROLE, _multiSigWallet);

        defiToken = _defiToken;
    }

    modifier onlyIbToken(address _sender)
    {
        require (deployedTokens.contains(_sender), "sender is not allowed");
        _;
    }

    /** @notice Called by ibDeepFy, deposits tokens into the adapter.
     * @dev Deposits funds, checks whether adapter is filled or insufficient, and then acts accordingly.
     ** @param _token Address of token (USDC, DAI, USDT...)
     ** @param _amount Amount of tokens in correct deimals (10**18 for DAI, 10**6 for USDT)
     */
    function deposit(address _token, uint256 _amount)
        external
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {

    }

    /** @notice Called by ibDeepFy, withdraws deposited user assets.
     ** @param _user Address of depositor
     ** @param _token Address of token (USDC, DAI, USDT...)
     ** @param _amount Amount
     */
    function withdraw(
        address _user,
        address _token,
        uint256 _amount
    ) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20Upgradeable(_token).safeTransfer(_user, _amount);
    }

    /** @notice Called by ibDeepFy, withdraws claimable rewards .
     ** @param _to Address to send rewards 
     ** @param _amount Amount
     */

    function claimUserReward(address to, uint256 amount) external whenNotPaused onlyIbToken(msg.sender) {
        require (IERC20Upgradeable(defiToken).balanceOf(address(this)) >= amount, "All rewards has been distributed, try again later !");
        IERC20Upgradeable(defiToken).transfer(to, amount);
    }

    function getDeployedTokens() public view returns (address[] memory) {
        return deployedTokens.values();
    }
    
    /* ========== ADMIN CONFIGURATION ========== */

    function addToken(address _token) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        deployedTokens.add(_token);
        return true;
    }

    function deleteToken(address _token) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        deployedTokens.remove(_token);
        return true;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function grantRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        if (role == DEFAULT_ADMIN_ROLE) {
            require(account.isContract(), "Handler: Not contract");
        }
        _grantRole(role, account);
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
