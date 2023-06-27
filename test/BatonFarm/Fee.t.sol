// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../shared/Fixture.t.sol";

contract FeeTest is Fixture {
    BatonFarm farm;

    function setUp() public {
        vm.startPrank(owner);
        address batonFarmAddress =
            batonFactory.createFarmFromExistingPairETH{ value: 1 ether }(owner, address(ethPair), weekDuration);
        farm = BatonFarm(payable(batonFarmAddress));

        ethPairLpToken.transfer(user1, 10 ether);
        assertEq(ethPairLpToken.balanceOf(user1), 10 ether);
        vm.stopPrank();
    }

    function testShouldCalculatePercentCorrectly() public {
        uint256 percentAmount = farm.calculatePercentage(25 * 100, 1 ether);

        assertEq(percentAmount, (25 / 100) * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                            proposeNewRewardsFee
    //////////////////////////////////////////////////////////////*/

    function testProposeNewFeeOnlyCalledByBatonMonitor() public {
        vm.expectRevert("Caller is not BatonMonitor contract");
        batonFactory.proposeNewRewardsFee(100);
    }

    function testEffectOfProposeNewFeeShouldFailForOutOfBound() public {
        vm.startPrank(batonMonitor);
        uint256 thirtyPercent = 30 * 100;
        vm.expectRevert("must: _proposedRewardsFee <= 2500 bp");
        batonFactory.proposeNewRewardsFee(thirtyPercent);
        vm.stopPrank();
    }

    function testEffectOfProposeNewFee() public {
        vm.startPrank(batonMonitor);
        batonFactory.proposeNewRewardsFee(100);
        assertEq(batonFactory.proposedRewardsFee(), 100);
        assertEq(batonFactory.rewardsFeeProposalApprovalDate(), block.timestamp + 7 days);
        assertEq(batonFactory.batonRewardsFee(), 0);

        batonFactory.proposeNewRewardsFee(500);
        assertEq(batonFactory.proposedRewardsFee(), 500);
        assertEq(batonFactory.rewardsFeeProposalApprovalDate(), block.timestamp + 7 days);
        assertEq(batonFactory.batonRewardsFee(), 0);

        batonFactory.proposeNewRewardsFee(2500);
        assertEq(batonFactory.proposedRewardsFee(), 2500);
        assertEq(batonFactory.rewardsFeeProposalApprovalDate(), block.timestamp + 7 days);
        assertEq(batonFactory.batonRewardsFee(), 0);

        uint256 prevTime = block.timestamp;
        skip(1 days);

        vm.expectRevert("must: _proposedRewardsFee <= 2500 bp");
        batonFactory.proposeNewRewardsFee(2501);
        assertEq(batonFactory.proposedRewardsFee(), 2500);
        assertEq(batonFactory.rewardsFeeProposalApprovalDate(), prevTime + 7 days);
        assertEq(batonFactory.batonRewardsFee(), 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            setRewardsFeeRate
    //////////////////////////////////////////////////////////////*/

    function testSetFeeRateOnlyCalledByBatonMonitor() public {
        vm.expectRevert("Caller is not BatonMonitor contract");
        batonFactory.setRewardsFeeRate();
    }

    function testSetFeeRateWithoutProposal() public {
        vm.startPrank(batonMonitor);
        assertEq(batonFactory.proposedRewardsFee(), 0);
        assertEq(batonFactory.rewardsFeeProposalApprovalDate(), 0);
        assertEq(batonFactory.batonRewardsFee(), 0);
        vm.expectRevert("no fee proposal");
        batonFactory.setRewardsFeeRate();
        vm.stopPrank();
    }

    function testCallSetFeeRateBeforePropsalTime() public {
        vm.startPrank(batonMonitor);
        batonFactory.proposeNewRewardsFee(500);
        assertEq(batonFactory.proposedRewardsFee(), 500);
        assertEq(batonFactory.rewardsFeeProposalApprovalDate(), block.timestamp + 7 days);

        vm.expectRevert("must: rewardsFeeProposalApprovalDate < block.timestamp");
        batonFactory.setRewardsFeeRate();
        vm.stopPrank();
    }

    function testCallSetFeeRate() public {
        vm.startPrank(batonMonitor);
        batonFactory.proposeNewRewardsFee(500);
        assertEq(batonFactory.proposedRewardsFee(), 500);
        assertEq(batonFactory.batonRewardsFee(), 0);
        assertEq(batonFactory.rewardsFeeProposalApprovalDate(), block.timestamp + 7 days);

        skip(7 days);
        vm.expectRevert("must: rewardsFeeProposalApprovalDate < block.timestamp");
        batonFactory.setRewardsFeeRate();

        skip(1 days);
        batonFactory.setRewardsFeeRate();
        assertEq(batonFactory.batonRewardsFee(), 500);
        assertEq(batonFactory.rewardsFeeProposalApprovalDate(), 0);

        vm.expectRevert("no fee proposal");
        batonFactory.setRewardsFeeRate();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            proposeNewLPFee
    //////////////////////////////////////////////////////////////*/

    function testProposeNewLPFeeCalledByBatonMonitor() public {
        vm.expectRevert("Caller is not BatonMonitor contract");
        batonFactory.proposeNewLPFee(100);
    }

    function testEffectOfProposeNewFLPeeShouldFailForOutOfBound() public {
        vm.startPrank(batonMonitor);
        uint256 thirtyPercent = 30 * 100;
        vm.expectRevert("must: _proposedLPFee <= 2500 bp");
        batonFactory.proposeNewLPFee(thirtyPercent);
        vm.stopPrank();
    }

    function testEffectOfproposeNewLPFee() public {
        vm.startPrank(batonMonitor);
        batonFactory.proposeNewLPFee(100);
        assertEq(batonFactory.proposedLPFee(), 100);
        assertEq(batonFactory.LPFeeProposalApprovalDate(), block.timestamp + 7 days);
        assertEq(batonFactory.batonLPFee(), 0);

        batonFactory.proposeNewLPFee(500);
        assertEq(batonFactory.proposedLPFee(), 500);
        assertEq(batonFactory.LPFeeProposalApprovalDate(), block.timestamp + 7 days);
        assertEq(batonFactory.batonRewardsFee(), 0);

        batonFactory.proposeNewLPFee(2500);
        assertEq(batonFactory.proposedLPFee(), 2500);
        assertEq(batonFactory.LPFeeProposalApprovalDate(), block.timestamp + 7 days);
        assertEq(batonFactory.batonLPFee(), 0);

        uint256 prevTime = block.timestamp;
        skip(1 days);

        vm.expectRevert("must: _proposedLPFee <= 2500 bp");
        batonFactory.proposeNewLPFee(2501);
        assertEq(batonFactory.proposedLPFee(), 2500);
        assertEq(batonFactory.LPFeeProposalApprovalDate(), prevTime + 7 days);
        assertEq(batonFactory.batonLPFee(), 0);
        vm.stopPrank();
    }

    function testSetLPFee() public {
        vm.startPrank(batonMonitor);
        uint256 onePercent = 100;
        batonFactory.proposeNewLPFee(onePercent);
        assertEq(batonFactory.LPFeeProposalApprovalDate(), block.timestamp + 7 days);

        skip(8 days);

        batonFactory.setLPFeeRate();
        assertEq(batonFactory.batonLPFee(), onePercent);
        vm.stopPrank();
    }
}
