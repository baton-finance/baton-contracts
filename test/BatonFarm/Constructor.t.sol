// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BatonFarm, ERC721 } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract ConstructorTest is Fixture {
    function testInitsStateVars() public {
        address owner = address(0x123);
        address rewardsDistributor = address(0x234);
        address batonMonitor = address(0x345);
        address rewardsToken = address(0xbabe);
        address pairAddress = address(ethPair);
        uint256 rewardsDuration = 123;

        BatonFarm farm = new BatonFarm(
            owner,
            rewardsDistributor,
            batonMonitor,
            rewardsToken,
            pairAddress,
            rewardsDuration,
            address(batonFactory)
        );

        assertEq(farm.owner(), owner);
        assertEq(farm.rewardsDistributor(), rewardsDistributor);
        assertEq(farm.batonMonitor(), batonMonitor);
        assertEq(address(farm.rewardsToken()), rewardsToken);
        assertEq(address(farm.pair()), pairAddress);
        assertEq(farm.rewardsDuration(), rewardsDuration);
        assertEq(farm.owner(), owner);
        assertEq(address(farm.stakingToken()), address(ethPair.lpToken()));
        assertEq(ERC721(ethPair.nft()).isApprovedForAll(address(farm), address(ethPair)), true);
    }
}
