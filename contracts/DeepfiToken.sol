// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IDeepFiERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

    
// 2M auto mint & 8M on 1 year, then 1M each year 

contract DeepfiToken is Initializable, IDeepFiERC20, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public lastMintTime;
    uint256 private constant mintInterval = 365 days; 

    uint256 public firstFundingLastMintTime;
    uint256 private constant firstFundingMintInterval = 30 days;
    uint8 public firstFundingCount; 

    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }
    

    function initialize(address _admin) initializer public {
        __ERC20_init("DefiToken", "DEFI");
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _mint(_admin, 2000000 * 10 ** decimals());
        _grantRole(MINTER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        lastMintTime = block.timestamp;
        firstFundingLastMintTime = block.timestamp;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function firstFunding(address to) public onlyRole(MINTER_ROLE) {
        require(block.timestamp >= firstFundingLastMintTime + firstFundingMintInterval, "Minting not allowed yet");
        require(firstFundingCount <= 12);
        _mint(to, ((8000000 * 10 ** decimals()) / 12));
        firstFundingLastMintTime = block.timestamp;
        firstFundingCount++;
    }

    // mint 1m each year
    function mint(address to) public onlyRole(MINTER_ROLE) {
        require(block.timestamp >= lastMintTime + mintInterval, "Minting not allowed yet");
        _mint(to, 1000000 * 10 ** decimals());
        lastMintTime = block.timestamp;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}
}