// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "./interfaces/ILiquidityHandler.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./DeepfiToken.sol";

contract D_Vault_SingleReward is 
        Initializable,
        PausableUpgradeable,
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

    IERC20Upgradeable public stakingToken;
    IERC20Upgradeable public rewardsToken;

    string public vaultName;
    // Total staked
    uint256 public totalSupply;
    // Time for rewards to be paid in seconds
    uint256 public duration;
    // Timestamp of reward ending
    uint256 public finishAt;
    // Minimum of last updated time and reward finish time
    uint256 public updatedAt;
    // Reward in seconds
    uint256 public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint256 public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint256) public userRewardPerTokenPaid;
    // User address =>  rewards to be claimed
    mapping(address => uint256) public rewards;
    // user address => total user earned bal
    mapping(address => uint256) public earned;
    // User address => staked amount
    mapping(address => uint256) public balanceOf;


    // event BurnedForWithdraw(address indexed user, uint256 amount);
    // event Deposited(address indexed user, address token, uint256 amount);
    // event NewHandlerSet(address oldHandler, address newHandler);
    // event UpdateTimeLimitSet(uint256 oldValue, uint256 newValue);
    
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



    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() initializer {}
    // // _disableInitializers();

    /**
    * function to initialize the contract
    * @param _stakingToken the address of the underlying token
    * @param _rewardsToken the address of the staking reward token 
    * @param _multiSigWallet the address of the multisig wallet associated with the contract
    * @param _handler the address of the liquidity handler contract
    */
    function initialize(
        string memory _vaultName,
        address _stakingToken,
        address _rewardsToken,
        address _multiSigWallet,
        address _handler
    ) initializer public {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(UPGRADER_ROLE, _multiSigWallet);
        _grantRole(PAUSER_ROLE, _multiSigWallet);

        vaultName = _vaultName;
 
        stakingToken = IERC20Upgradeable(_stakingToken);
        rewardsToken = IERC20Upgradeable(_rewardsToken);

        liquidityHandler = _handler;
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

    // function rewardPerToken() public view returns (uint) {
    //     if (totalSupply == 0) {
    //         return rewardPerTokenStored;
    //     }

    //     return
    //         rewardPerTokenStored +
    //         (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
    //         totalSupply;
    // }

    // function getRewardBalance(address _account) public view returns (uint) {
    //     return balanceOf[_account] * (
    //         (rewardPerToken() - userRewardPerTokenPaid[_account]) / 1e18
    //     ) + rewards[_account];
    // }
    function rewardPerToken() public view returns (uint256) {
    if (totalSupply == 0) {
        return rewardPerTokenStored;
    }

    uint256 rewardDuration = lastTimeRewardApplicable() - updatedAt;
    uint256 rewardRatePerToken = rewardRate * rewardDuration * 1e18 / totalSupply;
    return rewardPerTokenStored + rewardRatePerToken;
}

function getRewardBalance(address _account) public view returns (uint256) {
    uint256 earnedReward = rewards[_account];
    uint256 accountRewardPerTokenPaid = userRewardPerTokenPaid[_account];
    uint256 rewardPerTokenDiff = rewardPerToken() - accountRewardPerTokenPaid;
    uint256 reward = balanceOf[_account] * rewardPerTokenDiff / 1e18;
    return earnedReward + reward;
}

    /// @notice  Deposit user assets .
    /// @dev When called, reward is updated, then asset token is sent to the LiquidityHandler
    /// @param _amount Amount to deposit

    function deposit(uint256 _amount) external whenNotPaused updateReward(msg.sender) {
        require(_amount > 0, "Vault : Invalid amount");
        stakingToken.safeTransferFrom(msg.sender, address(liquidityHandler), _amount);
        ILiquidityHandler handler = ILiquidityHandler(liquidityHandler);
        handler.deposit(address(stakingToken), _amount); // protocol / token to claim
        
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;     
      
        // emit TransferAssetValue(address(0), _msgSender(), _amount, amountIn18);
        // emit Deposited(_msgSender(), stakeTokenAddress, _amount);
    }

    /// @notice  Withdraws assets deposited by msg.sender
    /// @dev When called, update user reward balance, and transfer underlying asset from liquidity handler
    /// @param _amount Amount to withdraw

    function withdraw(uint256 _amount) public updateReward(msg.sender) {
        require(balanceOf[msg.sender] >= _amount, "amount too hight / balance too low");
        // uint256 fees = (_amount * 100) / 10000;
        // uint256 finalAmout = _amount - fees;
        ILiquidityHandler handler = ILiquidityHandler(liquidityHandler);
        handler.withdraw(
            super._msgSender(),
            address(stakingToken),
            _amount
        );
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;

        // emit TransferAssetValue(_msgSender(), address(0), _amount);
        // emit BurnedForWithdraw(_msgSender(), _amount);
    }

    // / @notice  Claim reward earned by stacking assets
    // / @dev 
    // / @param _amount Amount to withdraw

    function claimReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            earned[msg.sender] += reward;
        }
    }

    function getStakeBalance(address _account) public view returns (uint) {
        return balanceOf[_account];
    }

    function getTotalUserEarned(address _account) public view returns (uint) {
        return earned[_account];
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function getStakeToken() public view returns (address) {
        return address(stakingToken);
    }

    function getRewardToken() public view returns (address) {
        return address(rewardsToken);
    }

    /* ========== ADMIN CONFIGURATION ========== */
    function setRewardsDuration(uint _duration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmount(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) updateReward(address(0)) {
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

    function setLiquidityHandler(address newHandler)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newHandler.isContract(), "Vault: Not contract");

        address oldValue = liquidityHandler;
        liquidityHandler = newHandler;
        // emit NewHandlerSet(oldValue, liquidityHandler);
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

    // function grantRole(bytes32 role, address account)
    //     public
    //     override
    //     onlyRole(getRoleAdmin(role))
    // {
    //     _grantRole(role, account);
    // }
    
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {
        require(upgradeStatus, "Vault: Upgrade not allowed");
        upgradeStatus = false;
    }
}
