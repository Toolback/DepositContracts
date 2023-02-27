// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.9;


// import "./interfaces/DefiERC20.sol";
// import "./interfaces/ILiquidityHandler.sol";

// import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";


// // import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// contract DefiLP is 
//         Initializable,
//         PausableUpgradeable,
//         DefiERC20,
//         AccessControlUpgradeable,
//         UUPSUpgradeable
// {
//     using AddressUpgradeable for address;
//     using SafeERC20Upgradeable for IERC20Upgradeable;

//     bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
//     bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

//     // current annual interest rate in % (10 = 10 APR)
//     uint256 public annualInterest;

//     // minimun time before a reward update between two user action
//     uint256 public updateTimeLimit;

//     // contract that will distribute money between the pool and the wallet
//     /// @custom:oz-renamed-from liquidityBuffer
//     address public liquidityHandler;

//     // flag for upgrades availability
//     bool public upgradeStatus;

//     // trusted forwarder address, see EIP-2771
//     address public trustedForwarder;

//     // token allowed to be deposited 
//     address public stakeTokenAddress;

//     // register user information
//     mapping (address => s_user) public user_data;

//     // struct of user data
//     struct s_user
//     {
//         address addr;
//         // uint256 bal_deposit;
//         uint256 bal_claimable;
//         uint256 bal_total_earned;
//         uint256 last_action_time;
//     }

//     // event BurnedForWithdraw(address indexed user, uint256 amount);
//     // event Deposited(address indexed user, address token, uint256 amount);
//     // event NewHandlerSet(address oldHandler, address newHandler);
//     // event UpdateTimeLimitSet(uint256 oldValue, uint256 newValue);
//     // event DepositTokenStatusChanged(address token, bool status);
    
//     // event InterestChanged(
//     //     uint256 oldYearInterest,
//     //     uint256 newYearInterest,
//     //     uint256 oldInterestPerSecond,
//     //     uint256 newInterestPerSecond
//     // );
    
//     // event TransferAssetValue(
//     //     address indexed from,
//     //     address indexed to,
//     //     uint256 tokenAmount,
//     //     uint256 assetValue,
//     //     uint256 growingRatio
//     // );



//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() {
//         _disableInitializers();
//     }

//     /**
//     * function to initialize the contract
//     * @param _name the name of the token
//     * @param _symbol the symbol of the token
//     * @param _underlying_address the address of the underlying token
//     * @param _multiSigWallet the address of the multisig wallet associated with the contract
//     * @param _handler the address of the liquidity handler contract
//     * @param _annualInterest the annual interest rate for the contract
//     * @param _trustedForwarder the address of the trusted forwarder
//     */
//     function initialize(
//         string memory _name,
//         string memory _symbol,
//         address _underlying_address,
//         address _multiSigWallet,
//         address _handler,
//         uint256 _annualInterest,
//         address _trustedForwarder
//     ) initializer public {
//         uint8 resDecimals = DefiERC20(_underlying_address).decimals();
//         __ERC20_init(_name, _symbol, resDecimals);
//         // __ERC20Burnable_init();
//         __Pausable_init();
//         __AccessControl_init();
//         __UUPSUpgradeable_init();

//         _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
//         _grantRole(UPGRADER_ROLE, _multiSigWallet);
//         // _grantRole(MINTER_ROLE, msg.sender);
//         _grantRole(PAUSER_ROLE, _multiSigWallet);
 
//         annualInterest = 10;
//         stakeTokenAddress = _underlying_address;
//         updateTimeLimit = 60;
//         liquidityHandler = _handler;
//         trustedForwarder = _trustedForwarder;
//     }

//     function getReward(address _userAddr) external view returns (uint256 claimableBal_) {
//             uint256 elapsedTime = block.timestamp - user_data[_userAddr].last_action_time;
//             // uint256 annualInterestDecimal = 0.1; 
//             claimableBal_ = (balanceOf(_userAddr) * annualInterest * elapsedTime) / (365 * 24 * 60 * 60);
//     }

//     /// @notice  Updates the user's claimable reward balance every time a user make an action
//     /// @dev 

//     function updateReward(address _userAddr) internal {
//         if (block.timestamp >= user_data[_userAddr].last_action_time + updateTimeLimit) {
//             // Calculer la rémunération accumulée de l'utilisateur en fonction du temps écoulé depuis sa dernière action et de son total stacked
//             uint256 elapsedTime = block.timestamp - user_data[_userAddr].last_action_time;
//             uint256 rewardAmount = (balanceOf(_userAddr) * annualInterest * elapsedTime) / (365 * 24 * 60 * 60);
//             // uint256 amountIn6 = rewardAmount * 1e6;
//             // uint256 amountIn18 = amountIn6 * 10**(18 - decimals());

//             // Update User Datas
//             user_data[_userAddr].last_action_time = block.timestamp;
//             user_data[_userAddr].bal_claimable += rewardAmount;
//             user_data[_userAddr].bal_total_earned += rewardAmount;
//         }
//         else 
//             return;
//     }

//     /// @notice  Deposit user assets and mint IbToken.
//     /// @dev When called, asset token is sent to the LiquidityHandler, then the reward is updated, and token minted
//     /// @param _amount Amount to deposit

//     function deposit(uint256 _amount) external whenNotPaused {
//         require(_amount > 0, "IBToken : Invalid amount");
//         // uint256 priceInWei = _amount * (10 ** decimals());
//         IERC20Upgradeable(stakeTokenAddress).safeTransferFrom(msg.sender,address(liquidityHandler),_amount);
        
//         updateReward(msg.sender);
//         // claim potential reward for protocol if theres any
//         // ILiquidityHandler(liquidityHandler).deposit(1, stakeTokenAddress); // protocol / token to claim
     
//         _mint(msg.sender, _amount);
      
//         // emit TransferAssetValue(address(0), _msgSender(), _amount, amountIn18);
//         // emit Deposited(_msgSender(), stakeTokenAddress, _amount);
//     }

//     /// @notice  Withdraws assets deposited
//     /// @dev When called, update user reward balance, then burn Ibtoken, and transfer underlying asset from liquidity handler
//     /// @param _recipient address to sent funds to
//     /// @param _amount Amount to withdraw

//     function withdrawTo(
//         address _recipient,
//         uint256 _amount
//     ) public {
//         // uint256 adjustedAmount = _amount * 10**(18 - decimals());
//         updateReward(_msgSender());
//         _burn(msg.sender, _amount);
//         ILiquidityHandler handler = ILiquidityHandler(liquidityHandler);
//         handler.withdraw(
//             _recipient,
//             stakeTokenAddress,
//             _amount
//         );
//         if (_recipient != _msgSender())
//             updateReward(_recipient);

//         // emit TransferAssetValue(_msgSender(), address(0), _amount);
//         // emit BurnedForWithdraw(_msgSender(), _amount);
//     }

//     /// @notice  Withdraws to msg.sender
//     /// @param _amount Amount to withdraw

//     function withdraw(uint256 _amount) external {
//         withdrawTo(_msgSender(), _amount);
//     }

//     /// @notice  Claim reward earned by stacking assets
//     /// @dev 
//     /// @param _amount Amount to withdraw

//     function requestRewards(uint256 _amount) external {
//         updateReward(msg.sender);
//         // uint256 priceInWei = _amount * (10 ** decimals());
//         require(user_data[msg.sender].bal_claimable >= _amount, "Not Enough Funds");
        
//         ILiquidityHandler handler = ILiquidityHandler(liquidityHandler);
//         handler.claimUserReward(
//             msg.sender,
//             _amount
//         );
//         user_data[msg.sender].bal_claimable -= _amount;
//     }

//     /**
//      * @dev See {IERC20-transfer}.
//      *
//      * Requirements:
//      *
//      * - `to` cannot be the zero address.
//      * - the caller must have a balance of at least `amount`.
//      */
//     function transfer(address _to, uint256 _amount) public override whenNotPaused returns (bool) {
//         address owner = _msgSender();
//         updateReward(owner);
//         // uint256 priceInWei = _amount * (10 ** decimals());
//         _transfer(owner, _to, _amount);
//         updateReward(_to);

//         // emit TransferAssetValue(owner, _to, _amount);
//         return true;
//     }

//     /**
//      * @dev See {IERC20-transferFrom}.
//      *
//      * Emits an {Approval} event indicating the updated allowance. This is not
//      * required by the EIP. See the note at the beginning of {ERC20}.
//      *
//      * NOTE: Does not update the allowance if the current allowance
//      * is the maximum `uint256`.
//      *
//      * Requirements:
//      *
//      * - `from` and `to` cannot be the zero address.
//      * - `from` must have a balance of at least `amount`.
//      * - the caller must have allowance for ``from``'s tokens of at least
//      * `amount`.
//      */
//     function transferFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) public override whenNotPaused returns (bool) {
//         address spender = _msgSender();
//         // uint256 priceInWei = amount * (10 ** decimals());
//         _spendAllowance(from, spender, amount);
//         updateReward(from);
//         _transfer(from, to, amount);
//         updateReward(to);        

//         // emit TransferAssetValue(from, to, amount);
//         return true;
//     }

//     function getStakeToken() public view returns (address) {
//         return stakeTokenAddress;
//     }

//     function isTrustedForwarder(address forwarder)
//         public
//         view
//         virtual
//         returns (bool)
//     {
//         return forwarder == trustedForwarder;
//     }

//     /* ========== ADMIN CONFIGURATION ========== */

//     function mint(address account, uint256 amount)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         _mint(account, amount);

//         // emit TransferAssetValue(address(0), _msgSender(), amount);
//     }

//     function burn(address account, uint256 amount)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         _burn(account, amount);

//         // emit TransferAssetValue(_msgSender(), address(0), amount);
//     }

//     /// @notice  Sets the new interest rate
//     /// @dev When called, it sets the new interest rate after updating the index.
//     /// @param _newAnnualInterest New annual interest rate with 2 decimals 850 == 8.50%
//     /// @param _newInterestPerSecond New interest rate = interest per second (100000000244041000*10**10 == 8% APY)

//     function setInterest(
//         uint256 _newAnnualInterest,
//         uint256 _newInterestPerSecond
//     ) public onlyRole(DEFAULT_ADMIN_ROLE) {
//         uint256 oldAnnualValue = annualInterest;
//         annualInterest = _newAnnualInterest;
//         // interestPerSecond = _newInterestPerSecond * 10**10;

//         // emit InterestChanged(
//         //     oldAnnualValue,
//         //     annualInterest
//         // );
//     }

//     function setUpdateTimeLimit(uint256 _newLimit)
//         public
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         uint256 oldValue = updateTimeLimit;
//         updateTimeLimit = _newLimit;

//         // emit UpdateTimeLimitSet(oldValue, _newLimit);
//     }


//     function setLiquidityHandler(address newHandler)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         require(newHandler.isContract(), "IBToken: Not contract");

//         address oldValue = liquidityHandler;
//         liquidityHandler = newHandler;
//         // emit NewHandlerSet(oldValue, liquidityHandler);
//     }

//     function setTrustedForwarder(address newTrustedForwarder)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         trustedForwarder = newTrustedForwarder;
//     }

//     function changeUpgradeStatus(bool _status)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         upgradeStatus = _status;
//     }

//     function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
//         _pause();
//     }

//     function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
//         _unpause();
//     }

//     function grantRole(bytes32 role, address account)
//         public
//         override
//         onlyRole(getRoleAdmin(role))
//     {
//         if (role == DEFAULT_ADMIN_ROLE) {
//             require(account.isContract(), "IBToken: Not contract");
//         }
//         _grantRole(role, account);
//     }

//     function _transfer(
//         address from,
//         address to,
//         uint256 amount
//     ) internal override {
//         super._transfer(from, to, amount);
//     }

//     function _burn(address account, uint256 amount) internal override {
//         super._burn(account, amount);
//     }

//     function _beforeTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) internal override {
//         super._beforeTokenTransfer(from, to, amount);
//     }

//     function _msgSender()
//         internal
//         view
//         virtual
//         override
//         returns (address sender)
//     {
//         if (isTrustedForwarder(msg.sender)) {
//             // The assembly code is more direct than the Solidity version using `abi.decode`.
//             assembly {
//                 sender := shr(96, calldataload(sub(calldatasize(), 20)))
//             }
//         } else {
//             return super._msgSender();
//         }
//     }

//     function _msgData()
//         internal
//         view
//         virtual
//         override
//         returns (bytes calldata)
//     {
//         if (isTrustedForwarder(msg.sender)) {
//             return msg.data[:msg.data.length - 20];
//         } else {
//             return super._msgData();
//         }
//     }
    
//     function _authorizeUpgrade(address)
//         internal
//         override
//         onlyRole(UPGRADER_ROLE)
//     {
//         require(upgradeStatus, "IBToken: Upgrade not allowed");
//         upgradeStatus = false;
//     }
// }
