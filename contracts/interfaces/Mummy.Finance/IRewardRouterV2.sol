pragma solidity ^0.8.11;

interface IRewardRouterV2{
        function claim() external;

        function handleRewards(bool _shouldClaimGmx, bool _shouldStakeGmx, bool _shouldClaimEsGmx, bool _shouldStakeEsGmx, bool _shouldStakeMultiplierPoints, bool _shouldClaimWeth, bool _shouldConvertWethToEth) external;

    function compound() external;
}