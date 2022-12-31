// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.11;
// import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// // import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";

// import "./interfaces/IIbDeepFy.sol";
// import "./interfaces/IHandlerAdapter.sol";
// // import "../interfaces/IExchange.sol";
// import "hardhat/console.sol";

// contract LiquidityHandler is
//     Initializable,
//     PausableUpgradeable,
//     AccessControlUpgradeable,
//     UUPSUpgradeable
// {
//     using Address for address;
//     using SafeERC20Upgradeable for IERC20Upgradeable;
//     using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;

//     bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

//     //flag for upgrades availability
//     bool public upgradeStatus;

//     // full info about adapter
//     struct AdapterInfo {
//         string name; // USD Curve-Aave
//         uint256 percentage; //500 == 5.00%
//         address adapterAddress; // 0x..
//         bool status; // active
//     }

//     EnumerableMapUpgradeable.AddressToUintMap private ibDeepFyToAdapterId;
//     mapping(uint256 => AdapterInfo) public adapterIdsToAdapterInfo;

//     struct Withdrawal {
//         // address of user that did withdrawal
//         address user;
//         // address of token that user chose to receive
//         address token;
//         // amount to recieve
//         uint256 amount;
//         // withdrawal time
//         uint256 time;
//     }

//     struct WithdrawalSystem {
//         mapping(uint256 => Withdrawal) withdrawals;
//         uint256 lastWithdrawalRequest;
//         uint256 lastSatisfiedWithdrawal;
//         uint256 totalWithdrawalAmount;
//         bool resolverTrigger;
//     }

//     mapping(address => WithdrawalSystem) public ibDeepFyToWithdrawalSystems;

//     // Address of the exchange used to convert non-supportedToken deposits and withdrawals
//     // address public exchangeAddress;

//     //info about what adapter or ibDeepFy
//     event EnoughToSatisfy(
//         address ibDeepFy,
//         uint256 inPoolAfterDeposit,
//         uint256 totalAmountInWithdrawals
//     );

//     event WithdrawalSatisfied(
//         address ibDeepFy,
//         address indexed user,
//         address token,
//         uint256 amount,
//         uint256 queueIndex,
//         uint256 satisfiedTime
//     );

//     event AddedToQueue(
//         address ibDeepFy,
//         address indexed user,
//         address token,
//         uint256 amount,
//         uint256 queueIndex,
//         uint256 requestTime
//     );

//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() initializer {}

//     // constructor() {
//     //     _disableInitializers();
//     // }


//     function initialize(
//         address _multiSigWallet
//         // address _exchangeAddress
//     ) public initializer {
//         __Pausable_init();
//         __AccessControl_init();
//         __UUPSUpgradeable_init();

//         require(_multiSigWallet.isContract(), "Handler: Not contract");
//         // require(_exchangeAddress.isContract(), "Handler: Not contract");
//         // exchangeAddress = _exchangeAddress;
//         _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
//         _grantRole(UPGRADER_ROLE, _multiSigWallet);
//     }

//     /** @notice Called by ibDeepFy, deposits tokens into the adapter.
//      * @dev Deposits funds, checks whether adapter is filled or insufficient, and then acts accordingly.
//      ** @param _token Address of token (USDC, DAI, USDT...)
//      ** @param _amount Amount of tokens in correct deimals (10**18 for DAI, 10**6 for USDT)
//      */
//     function deposit(address _token, uint256 _amount)
//         external
//         whenNotPaused
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         uint256 amount18 = _amount *
//             10**(18 - ERC20Upgradeable(_token).decimals());

//         uint256 inAdapter = getAdapterAmount(msg.sender);
//         uint256 expectedAdapterAmount = getExpectedAdapterAmount(
//             msg.sender,
//             amount18
//         );

//         uint256 adapterId = ibDeepFyToAdapterId.get(msg.sender);
//         address adapter = adapterIdsToAdapterInfo[adapterId].adapterAddress;

//         IERC20Upgradeable(_token).safeTransfer(adapter, _amount);
//         if (inAdapter < expectedAdapterAmount) {
//             if (expectedAdapterAmount < inAdapter + amount18) {
//                 uint256 toWallet = inAdapter + amount18 - expectedAdapterAmount;
//                 uint256 leaveInPool = amount18 - toWallet;

//                 IHandlerAdapter(adapter).deposit(_token, amount18, leaveInPool);
//             } else {
//                 IHandlerAdapter(adapter).deposit(_token, amount18, amount18);
//             }
//         } else {
//             IHandlerAdapter(adapter).deposit(_token, amount18, 0);
//         }

//         WithdrawalSystem storage withdrawalSystem = ibDeepFyToWithdrawalSystems[
//             msg.sender
//         ];

//         if (
//             withdrawalSystem.totalWithdrawalAmount > 0 && !withdrawalSystem.resolverTrigger
//         ) {
//             uint256 inAdapterAfterDeposit = getAdapterAmount(msg.sender);
//             uint256 firstInQueueAmount = withdrawalSystem
//                 .withdrawals[withdrawalSystem.lastSatisfiedWithdrawal + 1].amount;
//             if (firstInQueueAmount <= inAdapterAfterDeposit) {
//                 withdrawalSystem.resolverTrigger = true;
//                 emit EnoughToSatisfy(
//                     msg.sender,
//                     inAdapterAfterDeposit,
//                     withdrawalSystem.totalWithdrawalAmount
//                 );
//             }
//         }
//     }

//     /** @notice Called by ibDeepFy, withdraws tokens from the adapter.
//      * @dev Attempt to withdraw. If there are insufficient funds, you are added to the queue.
//      ** @param _user Address of depositor
//      ** @param _token Address of token (USDC, DAI, USDT...)
//      ** @param _amount Amount of tokens in 10**18
//      */
//     function withdraw(
//         address _user,
//         address _token,
//         uint256 _amount
//     ) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
//         uint256 inAdapter = getAdapterAmount(msg.sender);

//         WithdrawalSystem storage withdrawalSystem = ibDeepFyToWithdrawalSystems[
//             msg.sender
//         ];
//         if (inAdapter >= _amount && withdrawalSystem.totalWithdrawalAmount == 0) {
//             uint256 adapterId = ibDeepFyToAdapterId.get(msg.sender);
//             address adapter = adapterIdsToAdapterInfo[adapterId].adapterAddress;
//             IHandlerAdapter(adapter).withdraw(_user, _token, _amount);
//             emit WithdrawalSatisfied(
//                 msg.sender,
//                 _user,
//                 _token,
//                 _amount,
//                 0,
//                 block.timestamp
//             );
//         } else {
//             uint256 lastWithdrawalRequest = withdrawalSystem
//                 .lastWithdrawalRequest;
//             withdrawalSystem.lastWithdrawalRequest++;
//             withdrawalSystem.withdrawals[
//                 lastWithdrawalRequest + 1
//             ] = Withdrawal({
//                 user: _user,
//                 token: _token,
//                 amount: _amount,
//                 time: block.timestamp
//             });
//             withdrawalSystem.totalWithdrawalAmount += _amount;
//             emit AddedToQueue(
//                 msg.sender,
//                 _user,
//                 _token,
//                 _amount,
//                 lastWithdrawalRequest + 1,
//                 block.timestamp
//             );
//         }
//     }


//     // function withdraw(
//     //     address _user,
//     //     address _token,
//     //     uint256 _amount,
//     //     address _outputToken
//     // ) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {

//     // }

//     // function _withdrawThroughExchange(
//     //     address _inputToken,
//     //     address _targetToken,
//     //     uint256 _amount18,
//     //     address _user
//     // ) internal {

//     // }

//     function satisfyAdapterWithdrawals(address _ibDeepFy) public whenNotPaused {
//         WithdrawalSystem storage withdrawalSystem = ibDeepFyToWithdrawalSystems[
//             _ibDeepFy
//         ];
//         uint256 lastWithdrawalRequest = withdrawalSystem.lastWithdrawalRequest;
//         uint256 lastSatisfiedWithdrawal = withdrawalSystem
//             .lastSatisfiedWithdrawal;

//         if (lastWithdrawalRequest != lastSatisfiedWithdrawal) {
//             uint256 inAdapter = getAdapterAmount(_ibDeepFy);
//             uint256 adapterId = ibDeepFyToAdapterId.get(_ibDeepFy);
//             address adapter = adapterIdsToAdapterInfo[adapterId].adapterAddress;
//             while (lastSatisfiedWithdrawal != lastWithdrawalRequest) {
//                 Withdrawal memory withdrawal = withdrawalSystem.withdrawals[
//                     lastSatisfiedWithdrawal + 1
//                 ];
//                 if (withdrawal.amount <= inAdapter) {
//                     IHandlerAdapter(adapter).withdraw(
//                         withdrawal.user,
//                         withdrawal.token,
//                         withdrawal.amount
//                     );

//                     inAdapter -= withdrawal.amount;
//                     withdrawalSystem.totalWithdrawalAmount -= withdrawal.amount;
//                     withdrawalSystem.lastSatisfiedWithdrawal++;
//                     lastSatisfiedWithdrawal++;

//                     if (withdrawalSystem.resolverTrigger) {
//                         withdrawalSystem.resolverTrigger = false;
//                     }

//                     emit WithdrawalSatisfied(
//                         _ibDeepFy,
//                         withdrawal.user,
//                         withdrawal.token,
//                         withdrawal.amount,
//                         lastSatisfiedWithdrawal,
//                         block.timestamp
//                     );
//                 } else {
//                     break;
//                 }
//             }
//         }
//     }

//     // function satisfyAllWithdrawals() external {
//     //     for (uint256 i = 0; i < ibDeepFyToAdapterId.length(); i++) {
//     //         (address ibDeepFy, ) = ibDeepFyToAdapterId.at(i);
//     //         satisfyAdapterWithdrawals(ibDeepFy);
//     //     }
//     // }

//     // function withdrawalInDifferentTokenPossible(
//     //     address _ibDeepFy,
//     //     uint256 _amount
//     // ) public view returns (bool) {

//     // }

//     function getAdapterAmount(address _ibDeepFy) public view returns (uint256) {
//         uint256 adapterId = ibDeepFyToAdapterId.get(_ibDeepFy);
//         address adapter = adapterIdsToAdapterInfo[adapterId].adapterAddress;

//         return IHandlerAdapter(adapter).getAdapterAmount();
//     }

//     function getExpectedAdapterAmount(address _ibDeepFy, uint256 _newAmount)
//         public
//         view
//         returns (uint256)
//     {
//         uint256 adapterId = ibDeepFyToAdapterId.get(_ibDeepFy);
//         uint256 percentage = adapterIdsToAdapterInfo[adapterId].percentage;

//         uint256 totalWithdrawalAmount = ibDeepFyToWithdrawalSystems[_ibDeepFy]
//             .totalWithdrawalAmount;

//         return
//             ((_newAmount + IIbDeepFy(_ibDeepFy).totalAssetSupply()) *
//                 percentage) /
//             10000 +
//             totalWithdrawalAmount;
//     }

//     function getAdapterId(address _ibDeepFy) external view returns (uint256) {
//         return ibDeepFyToAdapterId.get(_ibDeepFy);
//     }

//     function getIbDeepFyByAdapterId(uint256 _adapterId)
//         public
//         view
//         returns (address)
//     {
//         address ibDeepFy_;
//         uint256 numberOfIbDeepFys = ibDeepFyToAdapterId.length();

//         for (uint256 i = 0; i < numberOfIbDeepFys; i++) {
//             (address ibDeepFy, uint256 adapterId) = ibDeepFyToAdapterId.at(i);
//             if (adapterId == _adapterId) {
//                 ibDeepFy_ = ibDeepFy;
//                 break;
//             }
//         }
//         return ibDeepFy_;
//     }

//     function getListOfIbDeepFys() external view returns (address[] memory) {
//         uint256 numberOfIbDeepFys = ibDeepFyToAdapterId.length();
//         address[] memory ibDeepFys = new address[](numberOfIbDeepFys);
//         for (uint256 i = 0; i < numberOfIbDeepFys; i++) {
//             (ibDeepFys[i], ) = ibDeepFyToAdapterId.at(i);
//         }
//         return ibDeepFys;
//     }

//     function getLastAdapterIndex() public view returns (uint256) {
//         uint256 counter = 1;
//         while (true) {
//             if (adapterIdsToAdapterInfo[counter].adapterAddress == address(0)) {
//                 counter--;
//                 break;
//             } else {
//                 counter++;
//             }
//         }
//         return counter;
//     }

//     function getActiveAdapters()
//         external
//         view
//         returns (AdapterInfo[] memory, address[] memory)
//     {
//         uint256 numberOfIbDeepFys = ibDeepFyToAdapterId.length();
//         address[] memory ibDeepFys = new address[](numberOfIbDeepFys);
//         uint256[] memory adaptersId = new uint256[](numberOfIbDeepFys);
//         AdapterInfo[] memory adapters = new AdapterInfo[](numberOfIbDeepFys);
//         for (uint256 i = 0; i < numberOfIbDeepFys; i++) {
//             (ibDeepFys[i], adaptersId[i]) = ibDeepFyToAdapterId.at(i);
//             adapters[i] = adapterIdsToAdapterInfo[adaptersId[i]];
//         }
//         return (adapters, ibDeepFys);
//     }

//     function getAllAdapters()
//         external
//         view
//         returns (AdapterInfo[] memory, address[] memory)
//     {
//         uint256 numberOfAllAdapters = getLastAdapterIndex();

//         AdapterInfo[] memory adapters = new AdapterInfo[](numberOfAllAdapters);
//         address[] memory ibDeepFys = new address[](numberOfAllAdapters);

//         for (uint256 i = 0; i < numberOfAllAdapters; i++) {
//             adapters[i] = adapterIdsToAdapterInfo[i + 1];
//             ibDeepFys[i] = getIbDeepFyByAdapterId(i + 1);
//         }
//         return (adapters, ibDeepFys);
//     }

//     function getAdapterCoreTokensFromIbDeepFy(address _ibDeepFy)
//         public
//         view
//         returns (address, address)
//     {
//         uint256 adapterId = ibDeepFyToAdapterId.get(_ibDeepFy);
//         address adapterAddress = adapterIdsToAdapterInfo[adapterId]
//             .adapterAddress;
//         return (IHandlerAdapter(adapterAddress).getCoreTokens());
//     }

//     function getWithdrawal(address _ibDeepFy, uint256 _id)
//         external
//         view
//         returns (Withdrawal memory)
//     {
//         return ibDeepFyToWithdrawalSystems[_ibDeepFy].withdrawals[_id];
//     }

//     function isUserWaiting(address _ibDeepFy, address _user) external view returns(bool){
//         WithdrawalSystem storage withdrawalSystem = ibDeepFyToWithdrawalSystems[_ibDeepFy];
//         uint256 lastWithdrawalRequest = withdrawalSystem.lastWithdrawalRequest;
//         uint256 lastSatisfiedWithdrawal = withdrawalSystem.lastSatisfiedWithdrawal;
//         if(lastWithdrawalRequest != lastSatisfiedWithdrawal){
//             for(uint i = lastSatisfiedWithdrawal + 1; i <= lastWithdrawalRequest; i++){
//                 if(withdrawalSystem.withdrawals[i].user == _user){
//                     return true;
//                 }
//             }
//         }
//         return false;
//     }


//     /* ========== ADMIN CONFIGURATION ========== */

//     function setIbDeepFyToAdapterId(address _ibDeepFy, uint256 _adapterId)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         ibDeepFyToAdapterId.set(_ibDeepFy, _adapterId);
//     }

//     function setAdapter(
//         uint256 _id,
//         string memory _name,
//         uint256 _percentage,
//         address _adapterAddress,
//         bool _status
//     ) external onlyRole(DEFAULT_ADMIN_ROLE) {
//         require(_id != 0, "Handler: !allowed 0 id");
//         AdapterInfo storage adapter = adapterIdsToAdapterInfo[_id];

//         adapter.name = _name;
//         adapter.percentage = _percentage;
//         adapter.adapterAddress = _adapterAddress;
//         adapter.status = _status;
//     }

//     function changeAdapterStatus(uint256 _id, bool _status)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         adapterIdsToAdapterInfo[_id].status = _status;
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
//             require(account.isContract(), "Handler: Not contract");
//         }
//         _grantRole(role, account);
//     }

//     // function setExchangeAddress(address newExchangeAddress)
//     //     external
//     //     onlyRole(DEFAULT_ADMIN_ROLE)
//     // {
//     //     exchangeAddress = newExchangeAddress;
//     // }

//     /**
//      * @dev admin function for removing funds from contract
//      * @param _address address of the token being removed
//      * @param _amount amount of the token being removed
//      */
//     function removeTokenByAddress(
//         address _address,
//         address _to,
//         uint256 _amount
//     ) external onlyRole(DEFAULT_ADMIN_ROLE) {
//         IERC20Upgradeable(_address).safeTransfer(_to, _amount);
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