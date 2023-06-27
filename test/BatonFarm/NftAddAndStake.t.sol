// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonFactory } from "../../src/BatonFactory.sol";

import "../shared/Fixture.t.sol";

contract NftAddAndStakeTest is Fixture {
    uint256[] public tokenIdsToStake;
    BatonFarm public farm;

    event Staked(address indexed user, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);

        farm = batonFarmAddressPairNFT;
        bayc.setApprovalForAll(address(farm), true);
        for (uint256 i = 5; i < 10; i++) {
            bayc.mint(owner, i);
            tokenIdsToStake.push(i);
        }
        vm.stopPrank();
    }

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

    function testNftAddAndStake() public {
        vm.startPrank(owner);

        checkStateBeforeStake(farm);

        uint256 lpTokenAmount =
            farm.pair().addQuote(1 ether, tokenIdsToStake.length * 1e18, farm.pair().lpToken().totalSupply());
        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, 1 ether, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );

        assertEq(farm.totalSupply(), lpTokenAmount);
        assertEq(farm.stakingToken().balanceOf(address(farm)), lpTokenAmount);
        assertEq(farm.balanceOf(owner), lpTokenAmount);

        vm.stopPrank();
    }

    function testEmitsStakeEvent() public {
        uint256 lpTokenAmount =
            farm.pair().addQuote(1 ether, tokenIdsToStake.length * 1e18, farm.pair().lpToken().totalSupply());

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit Staked(owner, lpTokenAmount);
        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, lpTokenAmount, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );
    }

    function testAddsTokensToBalanceOf() public {
        uint256 lpTokenAmount =
            farm.pair().addQuote(1 ether, tokenIdsToStake.length * 1e18, farm.pair().lpToken().totalSupply());

        vm.startPrank(owner);
        uint256 balanceBefore = farm.balanceOf(owner);
        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, lpTokenAmount, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );
        assertEq(farm.balanceOf(owner), balanceBefore + lpTokenAmount);
    }

    function testAddsTokensToTotalSupply() public {
        uint256 lpTokenAmount =
            farm.pair().addQuote(1 ether, tokenIdsToStake.length * 1e18, farm.pair().lpToken().totalSupply());

        vm.startPrank(owner);
        uint256 totalSupplyBefore = farm.totalSupply();
        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, lpTokenAmount, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );
        assertEq(farm.totalSupply(), totalSupplyBefore + lpTokenAmount);
    }

    function testAddsTokensToStakingTokenBalance() public {
        uint256 lpTokenAmount =
            farm.pair().addQuote(1 ether, tokenIdsToStake.length * 1e18, farm.pair().lpToken().totalSupply());

        vm.startPrank(owner);
        uint256 stakingTokenBalanceBefore = farm.stakingToken().balanceOf(address(farm));
        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, lpTokenAmount, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );
        assertEq(farm.stakingToken().balanceOf(address(farm)), stakingTokenBalanceBefore + lpTokenAmount);
    }

    function testNftAddAndStake_noIds() public {
        vm.startPrank(owner);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);

        // Expect revert because there are no tokenIds (i.e input token amount is zero)
        vm.expectRevert("Input token amount is zero");
        farm.nftAddAndStake{ value: 0 ether }(
            tokenIdsToStake, 0 ether, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );
        vm.stopPrank();
    }

    function testNftAddAndStake_noApprovalThoughOwned() public {
        vm.startPrank(owner);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);
        bayc.setApprovalForAll(address(farm), false);

        // Expect revert because no approvals from the user on the BAYC collection
        // has been given
        vm.expectRevert("NOT_AUTHORIZED");
        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, 1 ether, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );

        vm.stopPrank();
    }

    function testNftAddAndStake_noApprovalBecauseNotOwned() public {
        vm.startPrank(address(0xBEEF));
        deal(address(0xBEEF), 1 ether);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);

        // Expect revert because the user doesn't own these NFTs
        vm.expectRevert("WRONG_FROM");
        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, 1 ether, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );

        vm.stopPrank();
    }

    function testNftAddAndStake_minLpTokenAmountTooHigh() public {
        vm.startPrank(owner);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);

        // Expect revert because slippage limit is unachieveable
        vm.expectRevert("Slippage: lp token amount out");
        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, 10_000 ether, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );

        vm.stopPrank();
    }

    function testNftAddAndStake_zeroETHincluded() public {
        vm.startPrank(owner);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);

        // Expect revert because no ETH is given
        vm.expectRevert("Input token amount is zero");
        farm.nftAddAndStake{ value: 0 ether }(
            tokenIdsToStake, 1 ether, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );

        vm.stopPrank();
    }

    function testNftAddAndStake_notEnoughETHIncluded() public {
        vm.startPrank(owner);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);

        // Expect revert because slippage limit is unachieveable (from unbalanced sides)
        vm.expectRevert("Slippage: lp token amount out");
        farm.nftAddAndStake{ value: 1 wei }(
            tokenIdsToStake, 1 ether, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );

        vm.stopPrank();
    }

    function testNftAddAndStake_zeroMinMaxPrice() public {
        vm.startPrank(owner);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);

        // Expect revert because slippage limit is unachieveable (from unbalanced sides)
        farm.nftAddAndStake{ value: 1 ether }(tokenIdsToStake, 1 ether, 0, 0, 0, proofs, reservoirOracleMessages);

        vm.stopPrank();
    }

    function testNftAddAndStake_minGreaterThanMax() public {
        vm.startPrank(owner);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);

        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, 1 ether, 10_000, 1000, 0, proofs, reservoirOracleMessages
        );

        vm.stopPrank();
    }

    function testNftAddAndStake_fakeProof() public {
        vm.startPrank(owner);
        BatonFarm farm = batonFarmAddressPairNFT;
        checkStateBeforeStake(farm);

        bytes32[] memory fakeProof;

        proofs.push(fakeProof);

        farm.nftAddAndStake{ value: 1 ether }(
            tokenIdsToStake, 1 ether, 10_000, 10_000, 0, proofs, reservoirOracleMessages
        );

        vm.stopPrank();
    }
}
