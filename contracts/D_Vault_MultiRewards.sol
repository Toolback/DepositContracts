// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/ILiquidityHandler.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract D_Vault_MultiRewards is 
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

    string public vaultName;
    // contract that will distribute assets between vaults and adapters
    address public liquidityHandler;

    IERC20Upgradeable public stakingToken;
    mapping(address => RewardToken) public rewardTokens;
    address[] public listedRewardTokens;
    mapping(address => bool) public isReward;


    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public rewards;

    // user address => reward token => total user earned bal
    mapping(address => mapping(address => uint256)) public totalClaimed;
    // User address => staked amount
    mapping(address => uint256) public balanceOf;
    // Total staked
    uint256 public totalSupply;
    // flag for upgrades availability
    bool public upgradeStatus;


    event Deposited(address indexed user, address token, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event removeToken(address indexed user, address indexed token, uint256 amount);
    event NewHandlerSet(address oldHandler, address newHandler);
    event UpdateRewardDuration(address rewardToken, uint256 oldValue, uint256 newValue);
    event UpdateRewardAmount(address rewardToken, uint256 amount);

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
    
    struct RewardToken {
        uint256 rewardDuration;        // Time for rewards to be paid in seconds
        uint256 periodFinish;           // Timestamp of reward ending
        uint256 rewardRate;             // Reward in seconds
        uint256 lastUpdateTime;         // Last Update
        uint256 rewardPerTokenStored;   // Sum of (reward rate * dt * 1e18 / total supply)
    }

    /**
    * function to initialize the contract
    * @param _vaultName the name of the vault
    * @param _stakingToken the address of the underlying token
    * @param _rewardTokens the address of the staking reward token 
    * @param _multiSigWallet the address of the multisig wallet associated with the contract
    * @param _handler the address of the liquidity handler contract
    */
    function initialize(
        string memory _vaultName,
        address _stakingToken,
        address[] memory _rewardTokens,
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
        for (uint i; i < _rewardTokens.length; i++) {
            if (_rewardTokens[i] != address(0)) {
                listedRewardTokens.push(_rewardTokens[i]);
                rewardTokens[_rewardTokens[i]].rewardDuration = 7 days;
                isReward[_rewardTokens[i]] = true;
            }
        }
    }
    /**
    * @notice  Updates the user's claimable reward balance every time a user make an action
    */
    modifier updateReward(address _account) {
        for (uint i; i < listedRewardTokens.length; i++) {
            address curr = listedRewardTokens[i];
            rewardTokens[curr].rewardPerTokenStored = rewardPerToken(curr);
            rewardTokens[curr].lastUpdateTime = _lastTimeRewardApplicable(curr);
            if (_account != address(0)) {
                rewards[_account][curr] = _getRewardBalance(_account, curr);
                userRewardPerTokenPaid[_account][curr] = rewardTokens[curr].rewardPerTokenStored;
            }
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
            msg.sender,
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
        for (uint i; i < listedRewardTokens.length; i++) {
            address currToken = listedRewardTokens[i];
            uint reward = rewards[msg.sender][currToken];
            if (reward > 0) {
                rewards[msg.sender][currToken] = 0;
                IERC20Upgradeable(currToken).transfer(msg.sender, reward);
                totalClaimed[msg.sender][currToken] += reward;
                emit Claim(msg.sender, reward);
            }
        }
    }

    function _lastTimeRewardApplicable(address _rewardToken) internal view returns (uint) {
        return _min(rewardTokens[_rewardToken].periodFinish, block.timestamp);
    }

    function rewardPerToken(address _rewardToken) public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardTokens[_rewardToken].rewardPerTokenStored;
        }

        uint256 rewardDuration = _lastTimeRewardApplicable(_rewardToken) - rewardTokens[_rewardToken].lastUpdateTime;
        uint256 rewardRatePerToken = rewardTokens[_rewardToken].rewardRate * rewardDuration * 1e18 / totalSupply;
        return rewardTokens[_rewardToken].rewardPerTokenStored + rewardRatePerToken;
    }
    /**
    * @notice  Retrieve user actual claimable balance.
    */
    function _getRewardBalance(address _account, address _rewardToken) internal view returns (uint256) {
        uint256 earnedReward = rewards[_account][_rewardToken];
        uint256 accountRewardPerTokenPaid = userRewardPerTokenPaid[_account][_rewardToken];
        uint256 rewardPerTokenDiff = rewardPerToken(_rewardToken) - accountRewardPerTokenPaid;
        uint256 reward = balanceOf[_account] * rewardPerTokenDiff / 1e18;
        return earnedReward + reward;
    }

    //should be same index as total earned 
    function getUserAllClaimableRewards(address _account) public view returns (uint256[] memory){
        uint256[] memory balances = new uint256[](listedRewardTokens.length);
        for (uint i; i < listedRewardTokens.length; i++) {
            balances[i] = _getRewardBalance(_account, listedRewardTokens[i]);
        }
        return balances;
    }

    function getUserAllEarnedRewards(address _account) public view returns (uint256[] memory){
        uint256[] memory balances = new uint256[](listedRewardTokens.length);
        for (uint i; i < listedRewardTokens.length; i++) {
            balances[i] = totalClaimed[_account][listedRewardTokens[i]];
        }
        return balances;
    }

    function getUserBals(address _account) external view returns (UserBals memory bals_)
    {
        uint256[] memory usrClaimable = getUserAllClaimableRewards(_account);
        uint256[] memory  usrTotalEarned = getUserAllEarnedRewards(_account);
        
        bals_.userDeposit = balanceOf[_account];
        bals_.userClaimable = usrClaimable;
        bals_.userTotalEarned = usrTotalEarned;
    }
    /**
    * @notice  return _account staked assets amount
    */ 
    function getStakeBalance(address _account) external view returns (uint) {
        return balanceOf[_account];
    }

    function getVaultInfos() external view returns(VaultInfo memory info_)
    {
        address[] memory rewardToken = listedRewardTokens;

        info_.name = vaultName;
        info_.totalSupply = totalSupply;
        // info_.duration = duration;
        // info_.finishAt = finishAt;
        // info_.updatedAt = updatedAt;
        // info_.rewardRate = rewardRate;
        // info_.rewardPerTokenStored = rewardPerTokenStored;
        info_.stakingToken = address(stakingToken);
        info_.rewardsToken = rewardToken;
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    /* ========== ADMIN CONFIGURATION ========== */
     /**
     * @dev Update the reward distribution duration. Only callable by the contract owner.
     * @param _duration The new reward duration in seconds
     */
    function setRewardsDuration(uint _duration, address _rewardToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(rewardTokens[_rewardToken].periodFinish < block.timestamp, "Vault : reward duration not finished");
        uint256 oldDuration = rewardTokens[_rewardToken].rewardDuration;
        rewardTokens[_rewardToken].rewardDuration = _duration;
        emit UpdateRewardDuration(_rewardToken, oldDuration, _duration);
    }

    /**
     * @dev Update the reward rate. Only callable by the contract owner.
     * @param _amount The new reward amount to distribute
     */
    function notifyRewardAmount(uint _amount, address _rewardToken) external onlyRole(DEFAULT_ADMIN_ROLE) updateReward(address(0)) {
        require(isReward[_rewardToken], "Vault : Current token is not listed as reward" );
        IERC20Upgradeable(_rewardToken).safeTransferFrom(msg.sender, address(this), _amount);
        if (block.timestamp >= rewardTokens[_rewardToken].periodFinish) {
            rewardTokens[_rewardToken].rewardRate = _amount / rewardTokens[_rewardToken].rewardDuration;
        } else {
            uint remainingRewards = (rewardTokens[_rewardToken].periodFinish - block.timestamp) * rewardTokens[_rewardToken].rewardRate;
            rewardTokens[_rewardToken].rewardRate = (_amount + remainingRewards) / rewardTokens[_rewardToken].rewardDuration;
        }

        require(rewardTokens[_rewardToken].rewardRate > 0, "Vault : reward rate = 0");
        require(
            rewardTokens[_rewardToken].rewardRate * rewardTokens[_rewardToken].rewardDuration <= IERC20Upgradeable(_rewardToken).balanceOf(address(this)),
            "Vault : reward amount > balance"
        );

        rewardTokens[_rewardToken].periodFinish = block.timestamp + rewardTokens[_rewardToken].rewardDuration;
        rewardTokens[_rewardToken].lastUpdateTime = block.timestamp;
        emit UpdateRewardAmount(_rewardToken, _amount);
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

    function addRewardToken(address _rewardToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            isReward[_rewardToken] == false
            && rewardTokens[_rewardToken].rewardDuration == 0
            , "Vault : Token already listed"
        );
        require( _rewardToken != address(stakingToken), "Vault : Cannot use staking token as a reward");
        listedRewardTokens.push(_rewardToken);
        rewardTokens[_rewardToken].rewardDuration = 7 days;
        isReward[_rewardToken] = true;
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
