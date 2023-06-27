// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BatonFarm } from "../src/BatonFarm.sol";
import { BatonFactory } from "../src/BatonFactory.sol";

import "./shared/Fixture.t.sol";
import "forge-std/console.sol";

contract FarmTest is Fixture {
    uint256[] public tokenIdsToStake;

    function setUp() public { }

    function testInit() public {
        assertEq(address(batonFactory.weth()), address(weth));
        assertEq(address(batonFactory.caviar()), address(caviar));
        assertEq(batonFactory.batonMonitor(), address(batonMonitor));
    }

    function testCreateFarmFromExistingPairERC20() public {
        vm.startPrank(owner);
        usd.approve(address(batonFactory), 500 * 1e6);

        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairERC20(owner, address(usd), 100 * 1e6, address(ercPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));
        vm.stopPrank();

        assertEq(address(farm.rewardsToken()), address(usd));
        assertEq(address(farm.stakingToken()), address(ercPair.lpToken()));
        assertEq(usd.balanceOf(address(farm)), 99_792_000);
        assertEq(usd.balanceOf(address(farm.rewardsDistributor())), 531_200);
        assertEq(farm.lastUpdateTime(), block.timestamp);
        assertEq(farm.periodFinish(), block.timestamp + farm.rewardsDuration());
        assertGt(farm.rewardRate(), 0);
    }

    function testCreateFarmFromExistingPairETH() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        assertEq(address(farm.rewardsToken()), address(weth));
        assertEq(address(farm.stakingToken()), address(ethPair.lpToken()));
        assertEq(weth.balanceOf(address(farm)), 999_999_999_999_907_200);
        assertEq(weth.balanceOf(address(farm.rewardsDistributor())), 416_000);
        assertEq(farm.lastUpdateTime(), block.timestamp);
        assertEq(farm.periodFinish(), block.timestamp + farm.rewardsDuration());
        assertEq(farm.rewardRate(), 1 ether / weekDuration);
        vm.stopPrank();
    }

    function testCreateFarmFromExistingPairNFT() public {
        vm.startPrank(owner);
        bayc.setApprovalForAll(address(batonFactory), true);
        for (uint256 i = 5; i < 10; i++) {
            bayc.mint(owner, i);
            tokenIdsToStake.push(i);
        }

        address batonFarmAddress = batonFactory.createFarmFromExistingPairNFT(
            owner, address(bayc), tokenIdsToStake, weekDuration, address(wethPair), reservoirOracleMessages
        );
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        vm.stopPrank();

        assertEq(ERC20(address(farm.rewardsToken())).balanceOf(address(farm)), 4_999_999_999_999_536_000); // the 5 nfts
        assertEq(ERC20(address(farm.rewardsToken())).balanceOf(address(farm.rewardsDistributor())), 928_000); // the
            // surplus
        assertEq(farm.lastUpdateTime(), block.timestamp);
        assertEq(farm.periodFinish(), block.timestamp + farm.rewardsDuration());
        assertEq(farm.rewardRate(), 5 ether / weekDuration);
    }
}
