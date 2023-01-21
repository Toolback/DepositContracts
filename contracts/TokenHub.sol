// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.9;

// import "./DefiLP.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
// import "@openzeppelin/contracts/utils/Address.sol";

// contract TokenHub is
//     Initializable,
//     AccessControlUpgradeable,
//     PausableUpgradeable,
//     UUPSUpgradeable
// {
//     using Address for address;
//     using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

//     // list of deployed IbTokens
//     EnumerableSetUpgradeable.AddressSet private deployedTokens;

//     //flag for upgrades availability
//     bool public upgradeStatus;

//     // protocol liquidity handler
//     address public liquidityHandler;

//     bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");



//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() initializer {}
//     // constructor() {
//     //     _disableInitializers();
//     // }

//     function initialize(
//         address _multiSigWallet,
//         address _liquidityHandler
//     ) public initializer {
//         __Pausable_init();
//         __AccessControl_init();
//         __UUPSUpgradeable_init();

//         _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
//         _grantRole(UPGRADER_ROLE, _multiSigWallet);
//         liquidityHandler = _liquidityHandler;
//     }
    


//     function createNewIBToken(
//         string memory _name,
//         string memory _symbol,
//         uint8  _decimals,
//         address _underlying_address,
//         address _multiSigWallet,
//         address _handler,
//         uint256 _annualInterest,
//         address _trustedForwarder
//     ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (address deployedToken_){

//         deployedToken_ = address(new DefiLP());
//         deployedTokens.add(deployedToken_);
//         ILiquidityHandler(liquidityHandler).grantRole(DEFAULT_ADMIN_ROLE, deployedToken_);
//         DefiLP(deployedToken_).initialize(_name, _symbol, _decimals, _underlying_address, _multiSigWallet, _handler, _annualInterest, _trustedForwarder);
//     }

//     function getDeployedTokens() public view returns (address[] memory) {
//         return deployedTokens.values();
//     }

//     function deleteToken(address _token) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
//         deployedTokens.remove(_token);
//         return true;
//     }

//     function grantRole(bytes32 role, address account)
//         public
//         override
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         if (role == DEFAULT_ADMIN_ROLE) {
//             require(account.isContract(), "Handler: Not contract");
//         }
//         _grantRole(role, account);
//     }

//     function changeUpgradeStatus(bool _status)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         upgradeStatus = _status;
//     }

//     function _authorizeUpgrade(address newImplementation)
//         internal
//         override
//         onlyRole(UPGRADER_ROLE)
//     {
//         require(upgradeStatus, "Handler: Upgrade not allowed");
//         upgradeStatus = false;
//     }
// }

// // contract Pool is Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
// //     bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
// //     bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
// //     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

// //     // Taux d'intérêt en pourcentage (par exemple, 10 pour 10% APR)
// //     uint256 public interestRate;

// //     address public payingToken;
// //     address public ibToken;

// //     uint256 public pool_bal;

// //     // Mapping pour enregistrer les utilisateurs et leurs informations
// //     mapping (address => s_user) public user_data;

// //     /// @custom:oz-upgrades-unsafe-allow constructor
// //     constructor() {
// //         _disableInitializers();
// //     }

// //     function initialize(address _admin, address _payingToken, address _ibToken, uint256 _interestRate) initializer public {
// //         __Pausable_init();
// //         __AccessControl_init();
// //         __UUPSUpgradeable_init();

// //         _grantRole(DEFAULT_ADMIN_ROLE, _admin);
// //         _grantRole(PAUSER_ROLE, _admin);
// //         _grantRole(UPGRADER_ROLE, _admin);

// //         // Définir le taux d'intérêt initial à 10% APR
// //         payingToken= _payingToken;
// //         ibToken = _ibToken;
// //         interestRate = _interestRate;
// //     }

// //     function pause() public onlyRole(PAUSER_ROLE) {
// //         _pause();
// //     }

// //     function unpause() public onlyRole(PAUSER_ROLE) {
// //         _unpause();
// //     }

// //     // Fonction pour permettre aux utilisateurs de déposer des LP tokens
// //     function deposit(uint256 _bal_deposit) public whenNotPaused {
// //         // Vérifier que l'utilisateur envoie un montant de LP tokens valide
// //         require(_bal_deposit > 0, "Invalid LP amount");

// //         // Récupérer l'adresse de l'utilisateur qui appelle la fonction
// //         address userAddr = msg.sender;

// //         // Mettre à jour les informations sur l'utilisateur
// //         user_data[userAddr].addr = userAddr;
// //         user_data[userAddr].bal_deposit += _bal_deposit;
// //         user_data[userAddr].last_action_time = block.timestamp;
// //         pool_bal += _bal_deposit;

// //         IbToken(ibToken).mint(userAddr, _bal_deposit);
// //     }

// //     // Fonction pour permettre aux utilisateurs de retirer leurs LP tokens et leurs gains
// // function withdraw(uint256 _bal_withdraw) public whenNotPaused {
// //     // Récupérer l'adresse de l'utilisateur qui appelle la fonction
// //     address userAddr = msg.sender;

// //     // Vérifier que l'utilisateur a bien le droit de retirer les LP tokens demandés
// //     require(IbToken(ibToken).balanceOf(msg.sender) >= _bal_withdraw, "Not enough LP tokens");

// //     // Calculer la rémunération accumulée de l'utilisateur en fonction du temps écoulé depuis sa dernière action
// //     uint256 elapsedTime = block.timestamp - user_data[userAddr].last_action_time;
// //     uint256 rewardAmount = (interestRate * user_data[userAddr].bal_claimable * elapsedTime) / 1e18;

// //     // Mettre à jour les informations sur l'utilisateur
// //     user_data[userAddr].bal_deposit -= _bal_withdraw;
// //     user_data[userAddr].last_action_time = block.timestamp;
// //     user_data[userAddr].bal_claimable -= rewardAmount;
// //     user_data[userAddr].bal_total_earned += rewardAmount;
    
// //     pool_bal -= _bal_withdraw;
// //     // auto claim GLM gains

// //     // Verser la rémunération au token ERC20 dédié
// //     ERC20(payingToken).transfer(userAddr, rewardAmount);
// //     IbToken(ibToken).burn(_bal_withdraw);
// // }


// //     function getSummary() public view returns (
// //       uint interestRate_, uint totalBalance_, address payingTokenAddress_, address ibTokenAddress_
// //       ) {
// //           interestRate_ = interestRate;
// //           totalBalance_ = pool_bal;
// //           payingTokenAddress_ = payingToken;
// //           ibTokenAddress_ = ibToken;
// //     }
// //     //add manual claim GLM rewards

// //     // Fonction pour permettre aux admins de définir un nouveau taux d'intérêt
// // function setInterestRate(uint256 _interestRate) public onlyRole(ADMIN_ROLE) {
// //         interestRate = _interestRate;
// //     }
// // }
