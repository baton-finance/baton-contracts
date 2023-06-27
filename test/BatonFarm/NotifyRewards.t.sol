// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract GetRewardTest is Fixture {
    function setUp() public { }

    function testNotApproved() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        vm.expectRevert("ERC20: insufficient allowance");
        farm.notifyRewardAmount(1 ether);
        vm.stopPrank();
    }

    function testNotifyShouldBeMoreThenZero() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        vm.expectRevert("reward cannot be 0");
        farm.notifyRewardAmount(0);
        vm.stopPrank();
    }

    function testRevertForRewardsTooHigh() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        vm.expectRevert("ERC20: insufficient allowance");
        farm.notifyRewardAmount(10 ether);
        vm.stopPrank();
    }

    function testRevertIfRewardIsGreaterThenBalance() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        weth.transfer(address(farm), 1 ether);

        vm.expectRevert("ERC20: insufficient allowance");
        farm.notifyRewardAmount(2 ether);
        vm.stopPrank();
    }

    function testNotifyRewardAmountShouldNotExtendBeforeDone() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        ethPairLpToken.transfer(user1, 1 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 1 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 1 ether);
        farm.stake(1 ether);
        vm.stopPrank();

        skip(3 days);

        vm.startPrank(user1);
        skip(7 days);
        farm.harvest();
        vm.stopPrank();
    }

    function testNotifyRewardAmountShouldNotUpdatePeriodFinish() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        uint256 initialPeriodFinish = farm.periodFinish();
        vm.stopPrank();

        assertEq(initialPeriodFinish, farm.periodFinish());
    }

    function testNotifyRewardAmountShouldUpdatePeriodFinish() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        uint256 initialPeriodFinish = farm.periodFinish();
        skip(8 days);
        farm.notifyRewardAmount(1 ether);
        vm.stopPrank();

        assertEq(initialPeriodFinish + 8 days, farm.periodFinish());
    }

    function testNotifyRewardAmountShouldUpdatePeriodFinishForNewDuration() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        skip(8 days);

        farm.setRewardsDuration(1 days);
        farm.notifyRewardAmount(1 ether);
        vm.stopPrank();

        assertEq(block.timestamp + 1 days, farm.periodFinish());
    }
}
