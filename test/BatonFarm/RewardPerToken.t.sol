// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../shared/Fixture.t.sol";

contract GetRewardTest is Fixture {
    function setUp() public { }

    function testRewardPerTokenShouldReturnZero() public {
        assertEq(batonFarmAddressPairNFT.rewardPerToken(), 0);
    }

    function testRewardPerToken() public {
        vm.startPrank(owner);
        weth.approve(address(batonFactory), 100 ether);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        BatonFarm farm = BatonFarm(payable(batonFarmAddress));

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        ethPairLpToken.approve(address(farm), 100 ether);
        farm.stake(1 ether);

        assertGt(farm.totalSupply(), 0);

        skip(1 days);

        assertGt(farm.rewardPerToken(), 0);
        vm.stopPrank();
    }
}
