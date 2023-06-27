// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract MigrationTest is Fixture {
    BatonFarm testFarm;

    function setUp() public {
        vm.startPrank(owner);
        usd.approve(address(batonFactory), 100 * 1e6);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairERC20(owner, address(usd), 100 * 1e6, address(ercPair), weekDuration);

        testFarm = BatonFarm(payable(batonFarmAddress));

        ercPairLpToken.transfer(user1, 10 ether);
        assertEq(ercPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();
    }

    function testCannotMigrateToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Please migrate to a valid address");
        testFarm.initiateMigration(address(0));
        vm.stopPrank();
    }

    function testShouldOnlyAllowOwnerToInitiateMigration() public {
        vm.startPrank(user1);
        vm.expectRevert("UNAUTHORIZED");
        testFarm.initiateMigration(babe);
        vm.stopPrank();

        vm.startPrank(owner);
        testFarm.initiateMigration(babe);
        vm.stopPrank();
    }

    function testShouldOnlyAllowBatonMonitorToExecuteMigration() public {
        vm.startPrank(owner);
        testFarm.initiateMigration(babe);

        vm.expectRevert("Caller is not BatonMonitor contract");
        testFarm.migrate();
        vm.stopPrank();

        vm.startPrank(batonMonitor);
        testFarm.migrate();
        vm.stopPrank();

        assertEq(testFarm.migrationComplete(), true);
        //should set periodFinish to current timestamp
        assertEq(testFarm.periodFinish(), block.timestamp);
    }

    function testShouldNotAllowNewStakesAfterMigrationIsComplete() public {
        vm.startPrank(owner);
        testFarm.initiateMigration(babe);

        vm.expectRevert("Caller is not BatonMonitor contract");
        testFarm.migrate();
        vm.stopPrank();

        vm.startPrank(batonMonitor);
        testFarm.migrate();
        vm.stopPrank();

        assertEq(testFarm.migrationComplete(), true);

        vm.expectRevert("This contract has been migrated, you cannot deposit new funds.");
        testFarm.stake(1 ether);
    }

    function testMigrateToSelf() public {
        vm.startPrank(owner);
        vm.expectRevert("Cannot migrate to self");
        testFarm.initiateMigration(address(testFarm));
        vm.stopPrank();
    }
}
