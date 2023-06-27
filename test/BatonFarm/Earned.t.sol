// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract EarnedTest is Fixture {
    function setUp() public { }

    function testShouldReturn0WhenNotStakeing() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        assertEq(farm.earned(owner), 0);
        vm.stopPrank();
    }

    function testShouldBeSomeValueWhenStaking() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(1 ether);

        skip(1 days);

        assertGt(farm.earned(user1), 0);

        vm.stopPrank();
    }

    function testShouldBeAbleToIncreaseRewardsBeforePoolEnds() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);

        uint256 rewardRateInitial = farm.rewardRate();
        weth.transfer(address(farm), 1 ether);
        farm.notifyRewardAmount(1 ether);
        uint256 rewardRateAfter = farm.rewardRate();

        assertGt(rewardRateInitial, 0);
        assertGt(rewardRateAfter, rewardRateInitial);
        vm.stopPrank();
    }

    function testShouldRolloverAfterDuration() public {
        //  1 eth - rewards
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(5000);

        skip(7 days);
        uint256 earnedFirst = farm.earned(user1);
        vm.stopPrank();

        vm.startPrank(owner);
        weth.transfer(address(farm), 1 ether);
        farm.notifyRewardAmount(1 ether);
        vm.stopPrank();

        skip(7 days);
        uint256 earnedSecond = farm.earned(user1);
        assertEq(earnedSecond, earnedFirst + earnedFirst);
    }
}
