// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract GetRewardTest is Fixture {
    function setUp() public { }

    function testGetReward() public {
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

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);
        farm.harvest();
        uint256 postRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 postEarnedBal = farm.earned(user1);

        assertLt(postEarnedBal, initialEarnedBal);
        assertGt(postRewardBal, initialRewardBal);
        vm.stopPrank();
    }

    function testGetRewardUSDC() public {
        vm.startPrank(owner);
        usd.approve(address(batonFactory), 500 * 1e6);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairERC20(owner, address(usd), 100 * 1e6, address(ercPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        ercPairLpToken.transfer(user1, 10 ether);
        assertEq(ercPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();
        vm.startPrank(user1);
        ercPairLpToken.approve(address(farm), 100 ether);
        farm.stake(1 ether);

        skip(1 days);

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);
        farm.harvest();
        uint256 postRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 postEarnedBal = farm.earned(user1);

        assertLt(postEarnedBal, initialEarnedBal);
        assertGt(postRewardBal, initialRewardBal);
        vm.stopPrank();
    }

    function testGetRewardUSDCWithFee() public {
        vm.startPrank(owner);
        usd.approve(address(batonFactory), 500 * 1e6);
        address batonFarmAddress = batonFactory.createFarmFromExistingPairERC20(
            owner, address(usd), 100 * 1e6, address(ercPair), monthDuration
        );
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        ercPairLpToken.transfer(user1, 10 ether);
        assertEq(ercPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(batonMonitor);
        batonFactory.proposeNewRewardsFee(500); // 5% fee
        skip(8 days);
        batonFactory.setRewardsFeeRate();
        assertEq(batonFactory.batonRewardsFee(), 500);
        vm.stopPrank();

        vm.startPrank(user1);
        ercPairLpToken.approve(address(farm), 100 ether);
        farm.stake(1 ether);

        skip(1 days);

        uint256 postEarnedBal = farm.earned(user1);

        farm.harvest();

        uint256 expectedFeeAmount = farm.calculatePercentage(500, postEarnedBal);

        assertEq(usd.balanceOf(user1) + usd.balanceOf(batonMonitor), postEarnedBal);
        assertEq(usd.balanceOf(user1), postEarnedBal - expectedFeeAmount);
        assertEq(usd.balanceOf(batonMonitor), expectedFeeAmount);
        vm.stopPrank();

        // set fees to 0
        vm.startPrank(batonMonitor);
        batonFactory.proposeNewRewardsFee(0); // 0% fee
        skip(8 days);
        batonFactory.setRewardsFeeRate();
        assertEq(batonFactory.batonRewardsFee(), 0);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 postEarnedBal2 = farm.earned(user1);
        farm.harvest();

        assertEq(usd.balanceOf(batonMonitor), expectedFeeAmount); // should stay same as before
        assertEq(usd.balanceOf(user1), (postEarnedBal - expectedFeeAmount) + postEarnedBal2);

        vm.stopPrank();
    }
}
