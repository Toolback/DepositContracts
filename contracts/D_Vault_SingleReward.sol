// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/ILiquidityHandler.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

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

    // contract that will distribute assets between vaults and adapters
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
    mapping(address => uint256) public totalClaimed;
    // User address => staked amount
    mapping(address => uint256) public balanceOf;


    event Deposited(address indexed user, address token, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event removeToken(address indexed user, address indexed token, uint256 amount);
    event NewHandlerSet(address oldHandler, address newHandler);
    event UpdateRewardDuration(uint256 oldValue, uint256 newValue);
    event UpdateRewardAmount(uint256 amount);

    struct VaultInfo {
        string name; // MLP 
        uint256 totalSupply; 
        uint256 duration; 
        uint256 finishAt; 
        uint256 updatedAt; 
        uint256 rewardRate; 
        uint256 rewardPerTokenStored;
        address stakingToken;
        address[] rewardsToken;
    }

    struct UserBals {
        uint256 userDeposit;
        uint256[] userClaimable;
        uint256[] userTotalEarned;
    }

    /**
    * function to initialize the contract
    * @param _vaultName the name of the vault
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
        liquidityHandler = _handler;
        stakingToken = IERC20Upgradeable(_stakingToken);
        rewardsToken = IERC20Upgradeable(_rewardsToken);
    }
    /**
    * @notice  Updates the user's claimable reward balance every time a user make an action
    */
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = getRewardBalance(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        
        _;
    }

    /**
    * @notice  Stake user assets.
    * @dev When called, reward is updated, then asset token is sent to the LiquidityHandler / Adapter
    * @param _amount Amount to deposit
    */
    function deposit(uint256 _amount) external whenNotPaused updateReward(msg.sender) {
        require(_amount > 0, "Vault : Invalid amount");
        stakingToken.safeTransferFrom(msg.sender, address(liquidityHandler), _amount);
        ILiquidityHandler handler = ILiquidityHandler(liquidityHandler);
        handler.deposit(address(stakingToken), _amount); // protocol / token to claim
        
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;     
      
        emit Deposited(msg.sender, address(stakingToken), _amount);
    }

    /**
    * @notice  Withdraws assets deposited by msg.sender
    * @dev When called, update user reward balance, and transfer underlying asset from liquidity handler
    * @param _amount Amount to withdraw
    */
    function withdraw(uint256 _amount) external whenNotPaused updateReward(msg.sender) {
        require(_amount > 0, "Vault : amount must be greater than 0");
        require(balanceOf[msg.sender] >= _amount, "Vault : amount too hight / balance too low");
        uint256 fees = _amount / 1000; //0.1% fees 
        uint256 finalAmount = _amount - fees;
        ILiquidityHandler handler = ILiquidityHandler(liquidityHandler);
        handler.withdraw(
            address(this),
            address(stakingToken),
            _amount,
            finalAmount,
            fees
        );
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        emit Withdraw(msg.sender, _amount);
    }

    /**
    * @notice  Claim all msg.sender rewards earned by stacking assets
    */ 
    function claimReward() external whenNotPaused updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            totalClaimed[msg.sender] += reward;
            emit Claim(msg.sender, reward);
        }
    }

    function lastTimeRewardApplicable() internal view returns (uint) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        uint256 rewardDuration = lastTimeRewardApplicable() - updatedAt;
        uint256 rewardRatePerToken = rewardRate * rewardDuration * 1e18 / totalSupply;
        return rewardPerTokenStored + rewardRatePerToken;
    }
    /**
    * @notice  Retrieve user actual claimable balance.
    */
    function getRewardBalance(address _account) internal view returns (uint256) {
        uint256 earnedReward = rewards[_account];
        uint256 accountRewardPerTokenPaid = userRewardPerTokenPaid[_account];
        uint256 rewardPerTokenDiff = rewardPerToken() - accountRewardPerTokenPaid;
        uint256 reward = balanceOf[_account] * rewardPerTokenDiff / 1e18;
        return earnedReward + reward;
    }

    //should be same index as total earned 
    function getUserAllClaimableRewards(address _account) external view returns (uint256[] memory){
        uint256[] memory balances = new uint256[](1);
        balances[0] = getRewardBalance(_account);
        return balances;
    }

    function getUserAllEarnedRewards(address _account) external view returns (uint256[] memory){
        uint256[] memory balances = new uint256[](1);
        balances[0] = totalClaimed[_account];
        return balances;
    }

    function getUserBals(address _account) external view returns (UserBals memory bals_)
    {
        bals_.userDeposit = balanceOf[_account];
        bals_.userClaimable[0] = getRewardBalance(_account);
        bals_.userTotalEarned[0] = totalClaimed[_account];

    }
    /**
    * @notice  return _account staked assets amount
    */ 
    function getStakeBalance(address _account) external view returns (uint) {
        return balanceOf[_account];
    }

    /**
    * @notice  return _account total claimed assets amount
    */ 
    function getTotalUserEarned(address _account) external view returns (uint) {
        return totalClaimed[_account];
    }

    function getVaultInfos() external view returns(VaultInfo memory info_)
    {
        info_.name = vaultName;
        info_.totalSupply = totalSupply;
        info_.duration = duration;
        info_.finishAt = finishAt;
        info_.updatedAt = updatedAt;
        info_.rewardRate = rewardRate;
        info_.rewardPerTokenStored = rewardPerTokenStored;
        info_.stakingToken = address(stakingToken);
        info_.rewardsToken[0] = address(rewardsToken);
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    /* ========== ADMIN CONFIGURATION ========== */
     /**
     * @dev Update the reward distribution duration. Only callable by the contract owner.
     * @param _duration The new reward duration in seconds
     */
    function setRewardsDuration(uint _duration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(finishAt < block.timestamp, "Vault : reward duration not finished");
        uint256 oldDuration = duration;
        duration = _duration;
        emit UpdateRewardDuration(oldDuration, _duration);
    }

    /**
     * @dev Update the reward rate. Only callable by the contract owner.
     * @param _amount The new reward amount per second
     */
    function notifyRewardAmount(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "Vault : reward rate = 0");
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "Vault : reward amount > balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
        emit UpdateRewardAmount(_amount);
    }

    /**
     * @dev Changes the liquidity handler contract address
     * @param _newHandler Address of the new liquidity handler contract
     */
    function setLiquidityHandler(address _newHandler)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_newHandler.isContract(), "Vault: Not contract");

        address oldValue = liquidityHandler;
        liquidityHandler = _newHandler;
        emit NewHandlerSet(oldValue, liquidityHandler);
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
    
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {
        require(upgradeStatus, "Vault: Upgrade not allowed");
        upgradeStatus = false;
    }
}
