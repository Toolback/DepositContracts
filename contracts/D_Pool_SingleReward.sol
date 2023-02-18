// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "./interfaces/DefiERC20.sol";
import "./interfaces/ILiquidityHandler.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";


// import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract D_Pool_SingleReward is 
        Initializable,
        PausableUpgradeable,
        // DefiERC20,
        AccessControlUpgradeable,
        UUPSUpgradeable
{
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    // contract that will distribute money between the pool and the handler
    /// @custom:oz-renamed-from liquidityBuffer
    address public liquidityHandler;

    // flag for upgrades availability
    bool public upgradeStatus;

    // trusted forwarder address, see EIP-2771
    address public trustedForwarder;

    IERC20Upgradeable public stakingToken;
    IERC20Upgradeable public rewardsToken;

    // Time for rewards to be paid in seconds
    uint public duration;
    // Timestamp of reward ending
    uint public finishAt;
    // Minimum of last updated time and reward finish time
    uint public updatedAt;
    // Reward in seconds
    uint public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public rewardPerTokenStored;
    // User address => token index => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // User address => token index => rewards to be claimed
    mapping(address => uint) public rewards;

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;


    // event BurnedForWithdraw(address indexed user, uint256 amount);
    // event Deposited(address indexed user, address token, uint256 amount);
    // event NewHandlerSet(address oldHandler, address newHandler);
    // event UpdateTimeLimitSet(uint256 oldValue, uint256 newValue);
    // event DepositTokenStatusChanged(address token, bool status);
    
    // event InterestChanged(
    //     uint256 oldYearInterest,
    //     uint256 newYearInterest,
    //     uint256 oldInterestPerSecond,
    //     uint256 newInterestPerSecond
    // );
    
    // event TransferAssetValue(
    //     address indexed from,
    //     address indexed to,
    //     uint256 tokenAmount,
    //     uint256 assetValue,
    //     uint256 growingRatio
    // );



    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
    * function to initialize the contract
    * @param _stakingToken the address of the underlying token
    * @param _rewardsToken the address of the staking reward token 
    * @param _multiSigWallet the address of the multisig wallet associated with the contract
    * @param _handler the address of the liquidity handler contract
    * @param _trustedForwarder the address of the trusted forwarder
    */
    function initialize(
        address _stakingToken,
        address _rewardsToken,
        address _multiSigWallet,
        address _handler,
        address _trustedForwarder
    ) initializer public {
        // uint8 resDecimals = DefiERC20(_underlying_address).decimals();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(UPGRADER_ROLE, _multiSigWallet);
        _grantRole(PAUSER_ROLE, _multiSigWallet);
 
        stakingToken = IERC20Upgradeable(_stakingToken);
        rewardsToken = IERC20Upgradeable(_rewardsToken);

        liquidityHandler = _handler;
        trustedForwarder = _trustedForwarder;
    }

    /// @notice  Updates the user's claimable reward balance every time a user make an action
    /// @dev 
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = getRewardBalance(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply;
    }
    /// @notice  Deposit user assets .
    /// @dev When called, reward is updated, then asset token is sent to the LiquidityHandler
    /// @param _amount Amount to deposit

    function deposit(uint256 _amount) external whenNotPaused updateReward(msg.sender) {
        require(_amount > 0, "IBToken : Invalid amount");
        // uint256 priceInWei = _amount * (10 ** decimals());
        stakingToken.safeTransferFrom(msg.sender,address(liquidityHandler),_amount);
        
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
        // claim potential reward for protocol if theres any
        // ILiquidityHandler(liquidityHandler).deposit(1, stakeTokenAddress); // protocol / token to claim
     
      
        // emit TransferAssetValue(address(0), _msgSender(), _amount, amountIn18);
        // emit Deposited(_msgSender(), stakeTokenAddress, _amount);
    }

    /// @notice  Withdraws assets deposited by msg.sender
    /// @dev When called, update user reward balance, and transfer underlying asset from liquidity handler
    /// @param _amount Amount to withdraw

    function withdraw(uint256 _amount) public updateReward(msg.sender) {
        // uint256 adjustedAmount = _amount * 10**(18 - decimals());
        ILiquidityHandler handler = ILiquidityHandler(liquidityHandler);
        handler.withdraw(
            msg.sender,
            address(stakingToken),
            _amount
        );

        // emit TransferAssetValue(_msgSender(), address(0), _amount);
        // emit BurnedForWithdraw(_msgSender(), _amount);
    }

    // / @notice  Claim reward earned by stacking assets
    // / @dev 
    // / @param _amount Amount to withdraw

    // function requestRewards(uint256 _amount) external {
    //     updateReward(msg.sender);
    //     // uint256 priceInWei = _amount * (10 ** decimals());
    //     require(user_data[msg.sender].bal_claimable >= _amount, "Not Enough Funds");
        
    //     ILiquidityHandler handler = ILiquidityHandler(liquidityHandler);
    //     handler.claimUserReward(
    //         msg.sender,
    //         _amount
    //     );
    //     user_data[msg.sender].bal_claimable -= _amount;
    // }

    function claimReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }
    function getRewardBalance(address _account) public view returns (uint) {
        return balanceOf[_account] * (
            (rewardPerToken() - userRewardPerTokenPaid[_account]) / 1e18
        ) + rewards[_account];
    }
    //     return
    //         ((balanceOf[_account] *
    //             (rewardPerToken(_tokenIndex) - userRewardPerTokenPaid[_account][_tokenIndex])) / 1e18) +
    //         rewards[_account][_tokenIndex];
    // }

    function setRewardsDuration(uint _duration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmount(
        uint _amount

    ) external onlyRole(DEFAULT_ADMIN_ROLE) updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "reward amount > balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function getStakeToken() public view returns (address) {
        return address(stakingToken);
    }

    function isTrustedForwarder(address forwarder)
        public
        view
        virtual
        returns (bool)
    {
        return forwarder == trustedForwarder;
    }

    /* ========== ADMIN CONFIGURATION ========== */

    // /// @notice  Sets the new interest rate
    // /// @dev When called, it sets the new interest rate after updating the index.
    // /// @param _newAnnualInterest New annual interest rate with 2 decimals 850 == 8.50%
    // /// @param _newInterestPerSecond New interest rate = interest per second (100000000244041000*10**10 == 8% APY)

    // function setInterest(
    //     uint256 _newAnnualInterest,
    //     uint256 _newInterestPerSecond
    // ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    //     uint256 oldAnnualValue = annualInterest;
    //     annualInterest = _newAnnualInterest;
    //     // interestPerSecond = _newInterestPerSecond * 10**10;

    //     // emit InterestChanged(
    //     //     oldAnnualValue,
    //     //     annualInterest
    //     // );
    // }

    // function setUpdateTimeLimit(uint256 _newLimit)
    //     public
    //     onlyRole(DEFAULT_ADMIN_ROLE)
    // {
    //     uint256 oldValue = updateTimeLimit;
    //     updateTimeLimit = _newLimit;

    //     // emit UpdateTimeLimitSet(oldValue, _newLimit);
    // }


    function setLiquidityHandler(address newHandler)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newHandler.isContract(), "IBToken: Not contract");

        address oldValue = liquidityHandler;
        liquidityHandler = newHandler;
        // emit NewHandlerSet(oldValue, liquidityHandler);
    }

    function setTrustedForwarder(address newTrustedForwarder)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        trustedForwarder = newTrustedForwarder;
    }

    function changeUpgradeStatus(bool _status)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        upgradeStatus = _status;
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
            require(account.isContract(), "IBToken: Not contract");
        }
        _grantRole(role, account);
    }

    // function _msgSender()
    //     internal
    //     view
    //     virtual
    //     override
    //     returns (address sender)
    // {
    //     if (isTrustedForwarder(msg.sender)) {
    //         // The assembly code is more direct than the Solidity version using `abi.decode`.
    //         assembly {
    //             sender := shr(96, calldataload(sub(calldatasize(), 20)))
    //         }
    //     } else {
    //         return super._msgSender();
    //     }
    // }
    
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {
        require(upgradeStatus, "IBToken: Upgrade not allowed");
        upgradeStatus = false;
    }
}
