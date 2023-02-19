pragma solidity ^0.8.9;

import "./D_Pool_SingleReward.sol";

contract test_update_pool is D_Pool_SingleReward {
        function version() public pure returns (string memory){
        return "v2!";
    }

}


