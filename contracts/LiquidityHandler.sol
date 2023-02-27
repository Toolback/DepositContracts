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
// import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";

// import "./interfaces/IBDeepfy.sol";
import "./interfaces/IAdapter.sol";
import "hardhat/console.sol";


import "hardhat/console.sol";

contract LiquidityHandler is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using Address for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    // using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    //flag for upgrades availability
    bool public upgradeStatus;

    // Protocol Governance Token used for rewarding user staking
    address public defiToken;

    // info about adapter
    struct AdapterInfo {
        string name; // MLP 
        uint256 percentage; //100 == 1.00%
        address adapterAddress; // 0x..
        bool status; // active
    }

    // list of deployed Pools
    EnumerableMapUpgradeable.AddressToUintMap private PoolToAdapterId;
    mapping(uint256 => AdapterInfo) public adapterIdsToAdapterInfo;


    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }


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

    modifier onlyPool(address _sender)
    {
        require (PoolToAdapterId.contains(_sender), "sender should be pool");
        _;
    }

    /** @notice Called by Deposit Pools, deposits tokens into the adapter.
     * @dev Deposits funds, checks whether adapter is filled or insufficient, and then acts accordingly.
     ** @param _token Address of token (USDC, DAI, USDT...)
     ** @param _amount Amount of tokens in correct deimals (10**18 for DAI, 10**6 for USDT)
     */
    function deposit(address _token, uint256 _amount)
        external
        whenNotPaused
        onlyPool(msg.sender)
    {
        uint256 adapterId = PoolToAdapterId.get(msg.sender);
        address adapter = adapterIdsToAdapterInfo[adapterId].adapterAddress;
        // uint256 leaveInPool = ;

        IERC20Upgradeable(_token).safeTransfer(adapter, _amount);
        IAdapter(adapter).deposit(_token, _amount);
    }

    /** @notice Called by Deposit Pools, withdraws deposited user assets.
     ** @param _user Address of depositor
     ** @param _token Address of token (USDC, DAI, USDT...)
     ** @param _amount Amount
     */
    function withdraw(
        address _user,
        address _token,
        uint256 _amount
    ) external whenNotPaused onlyPool(msg.sender) {
        // IERC20Upgradeable(_token).safeTransfer(_user, _amount);
        uint256 adapterId = PoolToAdapterId.get(msg.sender);
        address adapter = adapterIdsToAdapterInfo[adapterId].adapterAddress;
        IAdapter(adapter).withdraw(_user, _token, _amount);
    }

    function getAdapterId(address _pool) external view returns (uint256) {
        return PoolToAdapterId.get(_pool);
    }

    function getPoolByAdapterId(
        uint256 _adapterId
    ) public view returns (address) {
        address pool_;
        uint256 numberOfPools = PoolToAdapterId.length();

        for (uint256 i = 0; i < numberOfPools; i++) {
            (address pool, uint256 adapterId) = PoolToAdapterId.at(i);
            if (adapterId == _adapterId) {
                pool_ = pool;
                break;
            }
        }
        return pool_;
    }

    function getListOfPools() external view returns (address[] memory) {
        uint256 numberOfPools = PoolToAdapterId.length();
        address[] memory pools = new address[](numberOfPools);
        for (uint256 i = 0; i < numberOfPools; i++) {
            (pools[i], ) = PoolToAdapterId.at(i);
        }
        return pools;
    }

    function getLastAdapterIndex() public view returns (uint256) {
        uint256 counter = 1;
        while (true) {
            if (adapterIdsToAdapterInfo[counter].adapterAddress == address(0)) {
                counter--;
                break;
            } else {
                counter++;
            }
        }
        return counter;
    }

    function getActiveAdapters()
        external
        view
        returns (AdapterInfo[] memory, address[] memory)
    {
        uint256 numberOfPools = PoolToAdapterId.length();
        address[] memory pools = new address[](numberOfPools);
        uint256[] memory adaptersId = new uint256[](numberOfPools);
        AdapterInfo[] memory adapters = new AdapterInfo[](numberOfPools);
        for (uint256 i = 0; i < numberOfPools; i++) {
            (pools[i], adaptersId[i]) = PoolToAdapterId.at(i);
            adapters[i] = adapterIdsToAdapterInfo[adaptersId[i]];
        }
        return (adapters, pools);
    }

    function getAllAdapters()
        external
        view
        returns (AdapterInfo[] memory, address[] memory)
    {
        uint256 numberOfAllAdapters = getLastAdapterIndex();

        AdapterInfo[] memory adapters = new AdapterInfo[](numberOfAllAdapters);
        address[] memory pools = new address[](numberOfAllAdapters);

        for (uint256 i = 0; i < numberOfAllAdapters; i++) {
            adapters[i] = adapterIdsToAdapterInfo[i + 1];
            pools[i] = getPoolByAdapterId(i + 1);
        }
        return (adapters, pools);
    }
    // function getDeployedPools() public view returns (address[] memory) {
    //     return deployedPools.values();
    // }
    
    /* ========== ADMIN CONFIGURATION ========== */

    function setPoolToAdapterId(
        address _pool,
        uint256 _adapterId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolToAdapterId.set(_pool, _adapterId);
    }

    function setAdapter(
        uint256 _id,
        string memory _name,
        uint256 _percentage,
        address _adapterAddress,
        bool _status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_id != 0, "Handler: !allowed 0 id");
        AdapterInfo storage adapter = adapterIdsToAdapterInfo[_id];

        adapter.name = _name;
        adapter.percentage = _percentage;
        adapter.adapterAddress = _adapterAddress;
        adapter.status = _status;
    }

    function changeAdapterStatus(
        uint256 _id,
        bool _status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        adapterIdsToAdapterInfo[_id].status = _status;
    }

    // function addPool(address _pool) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
    //     deployedPools.add(_pool);
    //     return true;
    // }

    // function deletePool(address _pool) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
    //     deployedPools.remove(_pool);
    //     return true;
    // }

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
