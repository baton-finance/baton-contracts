// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract WithdrawlTest is Fixture {
    uint256[] public tokenIdsToStake;

    function setUp() public { }

    function testExit() public {
        //  1 eth - rewards
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(5000);

        skip(1 days);

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);

        farm.withdrawAndHarvest();

        uint256 postRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 postEarnedBal = farm.earned(user1);

        assertLt(postEarnedBal, initialEarnedBal);
        assertGt(postRewardBal, initialRewardBal);
        assertEq(postEarnedBal, 0);
        vm.stopPrank();
    }

    function testWithdraw() public {
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

        uint256 initialStakingTokenBal = farm.stakingToken().balanceOf(user1);
        uint256 initialStakeBal = farm.balanceOf(user1);

        farm.withdraw(1 ether);

        uint256 postStakingTokenBal = farm.stakingToken().balanceOf(user1);
        uint256 postStakeBal = farm.balanceOf(user1);

        assertEq(postStakeBal + 1 ether, initialStakeBal);
        assertEq(initialStakingTokenBal + 1 ether, postStakingTokenBal);
        vm.stopPrank();
    }

    function testCannotWithdrawlZero() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        vm.expectRevert("Cannot withdraw 0");
        farm.withdraw(0 ether);
        vm.stopPrank();
    }

    function testCannotWithdrawlMoreThenStaked() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        vm.expectRevert("Cannot withdraw more then you have staked");
        farm.withdraw(100 ether);
        vm.stopPrank();
    }

    function testWithdrawAndNftRemove() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        bayc.setApprovalForAll(address(farm), true);
        bayc.setApprovalForAll(address(farm.pair()), true);
        for (uint256 i = 5; i < 10; i++) {
            bayc.mint(owner, i);
            tokenIdsToStake.push(i);
        }

        farm.pair().nftAdd{ value: 1 ether }(
            1 ether, tokenIdsToStake, 0, 0, type(uint256).max, 0, proofs, reservoirOracleMessages
        );

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(1 ether);

        skip(1 days);

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);

        farm.withdrawAndRemoveLPFromPool(1 ether, 0, 0, 0);

        uint256 postRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 postEarnedBal = farm.earned(user1);

        assertEq(farm.pair().balanceOf(user1), 2_236_067_977_499_789_699);
        assertLt(postEarnedBal, initialEarnedBal);
        assertGt(postRewardBal, initialRewardBal);
        assertEq(postEarnedBal, 0);
        vm.stopPrank();
    }

    function testWithdrawAndNftRemove_amountZero() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        bayc.setApprovalForAll(address(farm), true);
        bayc.setApprovalForAll(address(farm.pair()), true);
        for (uint256 i = 5; i < 10; i++) {
            bayc.mint(owner, i);
            tokenIdsToStake.push(i);
        }

        farm.pair().nftAdd{ value: 1 ether }(
            1 ether, tokenIdsToStake, 0, 0, type(uint256).max, 0, proofs, reservoirOracleMessages
        );

        weth.deposit{ value: 1 ether }();
        //weth.transfer(address(farm), 1 ether);
        weth.approve(address(farm), 1 ether);
        farm.notifyRewardAmount(1 ether);

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(1 ether);

        skip(1 days);

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);

        vm.expectRevert("Cannot withdraw 0");
        farm.withdrawAndRemoveLPFromPool(0, 0, 0, 0);
        vm.stopPrank();
    }

    function testWithdrawAndNftRemove_minBaseTokenOutputAmountTooHigh() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        bayc.setApprovalForAll(address(farm), true);
        bayc.setApprovalForAll(address(farm.pair()), true);
        for (uint256 i = 5; i < 10; i++) {
            bayc.mint(owner, i);
            tokenIdsToStake.push(i);
        }

        farm.pair().nftAdd{ value: 1 ether }(
            1 ether, tokenIdsToStake, 0, 0, type(uint256).max, 0, proofs, reservoirOracleMessages
        );

        weth.deposit{ value: 1 ether }();
        weth.transfer(address(farm), 1 ether);
        farm.notifyRewardAmount(1 ether);

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(1 ether);

        skip(1 days);

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);

        vm.expectRevert("Slippage: base token amount out");
        farm.withdrawAndRemoveLPFromPool(1 ether, 10 ether, 0, 0);
        vm.stopPrank();
    }

    function testWithdrawAndNftRemove_minFractionalTokenOutputAmountTooHigh() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        weth.approve(address(farm), 1 ether);

        bayc.setApprovalForAll(address(farm), true);
        bayc.setApprovalForAll(address(farm.pair()), true);
        for (uint256 i = 5; i < 10; i++) {
            bayc.mint(owner, i);
            tokenIdsToStake.push(i);
        }

        farm.pair().nftAdd{ value: 1 ether }(
            1 ether, tokenIdsToStake, 0, 0, type(uint256).max, 0, proofs, reservoirOracleMessages
        );

        weth.deposit{ value: 1 ether }();
        weth.transfer(address(farm), 1 ether);
        farm.notifyRewardAmount(1 ether);

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(1 ether);

        skip(1 days);

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);

        vm.expectRevert("Slippage: fractional token out");
        farm.withdrawAndRemoveLPFromPool(1 ether, 0, 10 ether, 0);
        vm.stopPrank();
    }
}
