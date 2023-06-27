// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract StakeTest is Fixture {
    using stdStorage for StdStorage;

    uint256[] public tokenIdsToStake;

    event Staked(address indexed user, uint256 amount);

    function setUp() public { }

    function checkStateBeforeStake(BatonFarm farm) internal {
        assertEq(farm.totalSupply(), 0);
        assertEq(farm.balanceOf(owner), 0);
        assertEq(farm.stakingToken().balanceOf(address(farm)), 0);
    }

    function checkStateAfterStake(BatonFarm farm, uint256 amountStaked) internal {
        assertEq(farm.totalSupply(), amountStaked);
        assertEq(farm.balanceOf(owner), amountStaked);
        assertEq(farm.stakingToken().balanceOf(address(farm)), amountStaked);
    }

    function testShouldStakingIncreasesStakingBalance() public {
        vm.startPrank(owner);

        uint256 initialStakeBal = batonFarmAddressPairERC20.balanceOf(owner);
        uint256 initialLpBal = batonFarmAddressPairERC20.stakingToken().balanceOf(owner);

        batonFarmAddressPairERC20.stake(1 ether);

        uint256 postStakeBal = batonFarmAddressPairERC20.balanceOf(owner);
        uint256 postLpBal = batonFarmAddressPairERC20.stakingToken().balanceOf(owner);

        assertLt(postLpBal, initialLpBal);
        assertGt(postStakeBal, initialStakeBal);
        vm.stopPrank();
    }

    function testCannotStake() public {
        vm.expectRevert("Cannot stake 0");
        batonFarmAddressPairETH.stake(0);
    }

    function testStakeERC20() public {
        vm.startPrank(owner);
        checkStateBeforeStake(batonFarmAddressPairERC20);
        batonFarmAddressPairERC20.stake(1 ether);
        checkStateAfterStake(batonFarmAddressPairERC20, 1 ether);
        vm.stopPrank();
    }

    function testStakeETH() public {
        vm.startPrank(owner);
        checkStateBeforeStake(batonFarmAddressPairETH);
        batonFarmAddressPairETH.stake(1 ether);
        checkStateAfterStake(batonFarmAddressPairETH, 1 ether);
        vm.stopPrank();
    }

    function testStakeNFT() public {
        vm.startPrank(owner);
        checkStateBeforeStake(batonFarmAddressPairNFT);
        batonFarmAddressPairNFT.stake(1 ether);
        checkStateAfterStake(batonFarmAddressPairNFT, 1 ether);
        vm.stopPrank();
    }

    // === permissions ===

    function testWhenPoolActive() public {
        assertEq(batonFarmAddressPairETH.migrationComplete(), false);
        vm.startPrank(owner);
        batonFarmAddressPairETH.stake(1 ether);
        vm.stopPrank();
    }

    function testWhenPoolNotActive() public {
        assertEq(batonFarmAddressPairETH.migrationComplete(), false);
        migrateFarm(batonFarmAddressPairETH, owner);
        assertEq(batonFarmAddressPairETH.migrationComplete(), true);
        vm.startPrank(owner);
        vm.expectRevert("This contract has been migrated, you cannot deposit new funds.");
        batonFarmAddressPairETH.stake(1 ether);
        vm.stopPrank();
    }

    function testRevertIfPoolIsPaused() public {
        vm.prank(owner);
        batonFarmAddressPairETH.pause();

        vm.expectRevert("Pausable: paused");
        batonFarmAddressPairETH.stake(1 ether);
    }

    function testAddsTotalSupply() public {
        vm.startPrank(owner);
        batonFarmAddressPairETH.stake(1 ether);
        assertEq(batonFarmAddressPairETH.totalSupply(), 1 ether);
    }

    function testAddsToBalanceOf() public {
        vm.startPrank(owner);
        batonFarmAddressPairETH.stake(1 ether);
        assertEq(batonFarmAddressPairETH.balanceOf(owner), 1 ether);
    }

    function testAddsToStakingTokenBalance() public {
        vm.startPrank(owner);
        batonFarmAddressPairETH.stake(1 ether);
        assertEq(batonFarmAddressPairETH.stakingToken().balanceOf(address(batonFarmAddressPairETH)), 1 ether);
    }

    function testEmitsStakedEvent() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit Staked(owner, 1 ether);
        batonFarmAddressPairETH.stake(1 ether);
    }
}
