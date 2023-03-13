pragma solidity ^0.8.11;
import "./interfaces/Mummy.Finance/IRewardRouterV2.sol";

contract TestM {
    address payable public rewardRouteraddr = payable(0x7b9e962dd8AeD0Db9A1D8a2D7A962ad8b871Ce4F);


    function compound() public payable {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouteraddr);
        rewardRouter.handleRewards(true, true, true, true, true, true, true);
        // rewardRouter.compound();

    }

    function claim() public payable {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(rewardRouteraddr);
        rewardRouter.handleRewards(true, false, true, false, false, true, true);
    }

    receive() external payable{
    }
}