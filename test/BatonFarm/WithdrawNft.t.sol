// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract WithdrawlNft is Fixture {
    uint256[] public tokenIdsToStake;
    uint256[] public tokenIdToWithdraw;

    function setUp() public { }

    function testAmount0() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        // tokenIdsToStake is empty
        assertEq(tokenIdsToStake.length, 0);

        vm.expectRevert("Cannot withdraw 0");
        farm.withdrawAndRemoveNftFromPool(0, 0, 0, tokenIdsToStake, false);
        vm.stopPrank();
    }

    function testCannotWithdrawMoreThenStaked() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        bayc.setApprovalForAll(address(farm), true);
        bayc.setApprovalForAll(address(farm.pair()), true);
        ethPairLpToken.approve(address(farm), 100 ether);

        uint256 amountToStake = 1 ether;
        farm.stake(amountToStake);
        vm.expectRevert("Cannot withdraw more then you have staked");
        farm.withdrawAndRemoveNftFromPool(amountToStake + 1 ether, 0, 0, tokenIdsToStake, false);

        vm.stopPrank();
    }

    function testTakeFee() public {
        uint256 onePercent = 100;
        setLPFee(batonFactory, onePercent);

        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        bayc.setApprovalForAll(address(farm), true);
        bayc.setApprovalForAll(address(farm.pair()), true);
        for (uint256 i = 5; i < 9; i++) {
            bayc.mint(owner, i);
            tokenIdsToStake.push(i);
        }

        uint256 tt = farm.pair().nftAdd{ value: 1 ether }(
            1 ether, tokenIdsToStake, 0, 0, type(uint256).max, 0, proofs, reservoirOracleMessages
        );

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(tt);

        skip(1 days);

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);

        (uint256 base, uint256 frac) = farm.pair().removeQuote(tt);

        tokenIdToWithdraw.push(tokenIdsToStake[0]);
        tokenIdToWithdraw.push(tokenIdsToStake[1]);
        tokenIdToWithdraw.push(tokenIdsToStake[2]);

        farm.withdrawAndRemoveNftFromPool(tt, 0, 0, tokenIdToWithdraw, false);
        uint256 postRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 postEarnedBal = farm.earned(user1);

        assertEq(farm.pair().balanceOf(user1), 0);
        assertLt(postEarnedBal, initialEarnedBal);
        assertGt(postRewardBal, initialRewardBal);
        assertEq(postEarnedBal, 0);

        for (uint256 i = 0; i < tokenIdToWithdraw.length; i++) {
            assertEq(ERC721(farm.pair().nft()).ownerOf(tokenIdToWithdraw[i]), user1);
        }

        // cehck fee - no fee set
        assertEq(farm.pair().lpToken().balanceOf(batonMonitor), 19_999_999_999_999_000);

        vm.stopPrank();
    }

    function testwithdrawAndRemoveNftFromPool() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        bayc.setApprovalForAll(address(farm), true);
        bayc.setApprovalForAll(address(farm.pair()), true);
        for (uint256 i = 5; i < 9; i++) {
            bayc.mint(owner, i);
            tokenIdsToStake.push(i);
        }

        uint256 tt = farm.pair().nftAdd{ value: 1 ether }(
            1 ether, tokenIdsToStake, 0, 0, type(uint256).max, 0, proofs, reservoirOracleMessages
        );

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(tt);

        skip(1 days);

        uint256 initialRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 initialEarnedBal = farm.earned(user1);

        (uint256 base, uint256 frac) = farm.pair().removeQuote(tt);

        tokenIdToWithdraw.push(tokenIdsToStake[0]);
        tokenIdToWithdraw.push(tokenIdsToStake[1]);
        tokenIdToWithdraw.push(tokenIdsToStake[2]);

        farm.withdrawAndRemoveNftFromPool(tt, 0, 0, tokenIdToWithdraw, false);
        uint256 postRewardBal = farm.rewardsToken().balanceOf(user1);
        uint256 postEarnedBal = farm.earned(user1);

        assertEq(farm.pair().balanceOf(user1), 0);
        assertLt(postEarnedBal, initialEarnedBal);
        assertGt(postRewardBal, initialRewardBal);
        assertEq(postEarnedBal, 0);

        for (uint256 i = 0; i < tokenIdToWithdraw.length; i++) {
            assertEq(ERC721(farm.pair().nft()).ownerOf(tokenIdToWithdraw[i]), user1);
        }

        // cehck fee - no fee set
        assertEq(farm.pair().lpToken().balanceOf(batonMonitor), 0);

        vm.stopPrank();
    }
}
