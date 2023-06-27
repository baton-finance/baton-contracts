// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract LastTimeRewardApplicableTest is Fixture {
    function testShouldReturnZero() public {
        vm.startPrank(owner);
        BatonFarm farm =
            new BatonFarm(owner, owner, owner, address(weth), address(ethPair), weekDuration, address(batonFactory));
        weth.transfer(address(farm), 1 ether);

        assertEq(farm.lastTimeRewardApplicable(), 0);
        vm.stopPrank();
    }

    function testShouldUpdateCorrectly() public {
        vm.startPrank(owner);
        BatonFarm farm =
            new BatonFarm(owner, owner, owner, address(weth), address(ethPair), weekDuration, address(batonFactory));
        weth.approve(address(farm), 1 ether);

        farm.notifyRewardAmount(1 ether);
        uint256 currentTime = block.timestamp;
        uint256 lastTimeReward = batonFarmAddressPairETH.lastTimeRewardApplicable();

        assertEq(currentTime, lastTimeReward);
        vm.stopPrank();
    }
}
