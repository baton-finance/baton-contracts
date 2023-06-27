// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import "forge-std/Test.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockWETH } from "./mocks/MockWETH.sol";
import { MockERC721WithRoyalty } from "./mocks/MockERC721WithRoyalty.sol";

import { BatonFactory } from "../../src/BatonFactory.sol";
import { BatonFarm } from "../../src/BatonFarm.sol";
import { BatonZapRouterV1 } from "../../src/BatonZapRouterV1.sol";

import { Caviar } from "@caviar/src/Caviar.sol";
import { Pair } from "@caviar/src/Pair.sol";
import { LpToken } from "@caviar/src/LpToken.sol";
import { ReservoirOracle } from "@caviar/src/Pair.sol";

contract Fixture is Test {
    address public owner = vm.addr(1);
    address public user1 = vm.addr(2);
    address public user2 = vm.addr(3);
    address public batonMonitor = vm.addr(4);

    BatonZapRouterV1 public batonZapRouterV1;

    MockERC721WithRoyalty public bayc;
    MockERC20 public usd;
    MockWETH public weth;

    Caviar public caviar;

    Pair public ercPair;
    LpToken public ercPairLpToken;

    Pair public ethPair;
    LpToken public ethPairLpToken;

    Pair public wethPair;
    LpToken public wethPairLpToken;

    BatonFactory public batonFactory;

    address public babe = address(0xbabe);

    bytes32[][] public proofs;
    ReservoirOracle.Message[] public reservoirOracleMessages;

    uint256 monthDuration = 30 days;
    uint256 weekDuration = 7 days;
    uint256 dayDuration = 1 days;

    BatonFarm public batonFarmAddressPairNFT;
    BatonFarm public batonFarmAddressPairETH;
    BatonFarm public batonFarmAddressPairERC20;

    uint256[] public tokenIds;

    constructor() {
        caviar = new Caviar(address(0));
        batonZapRouterV1 = new BatonZapRouterV1();

        bayc = new MockERC721WithRoyalty("yeet", "YEET");
        usd = new MockERC20("us dollar", "USD", 6);
        weth = new MockWETH();

        ercPair = caviar.create(address(bayc), address(usd), bytes32(0));
        ercPairLpToken = LpToken(ercPair.lpToken());

        ethPair = caviar.create(address(bayc), address(0), bytes32(0));
        ethPairLpToken = LpToken(ethPair.lpToken());

        wethPair = caviar.create(address(bayc), address(weth), bytes32(0));
        wethPairLpToken = LpToken(ethPair.lpToken());

        batonFactory = new BatonFactory(payable(address(weth)), address(caviar), batonMonitor);

        deal(owner, 1000 ether);
        deal(address(weth), owner, 1000 ether);
        deal(address(ethPairLpToken), owner, 1000 ether);
        deal(address(ercPairLpToken), owner, 1000 ether);
        deal(address(wethPair), owner, 1000 ether);
        deal(address(usd), owner, 1000 * 1e6);

        vm.startPrank(owner);
        usd.approve(address(batonFactory), 1000 * 1e6);
        weth.approve(address(batonFactory), 100 ether);

        for (uint256 i = 0; i < 5; i++) {
            bayc.mint(owner, i);
            bayc.approve(address(batonFactory), i);
            tokenIds.push(i);
        }
        bayc.setApprovalForAll(address(batonFactory), true);

        batonFarmAddressPairERC20 = BatonFarm(
            payable(
                address(
                    batonFactory.createFarmFromExistingPairERC20(
                        owner, address(usd), 10 * 1e6, address(ercPair), weekDuration
                    )
                )
            )
        );
        ercPairLpToken.approve(address(batonFarmAddressPairERC20), 100 ether);

        batonFarmAddressPairETH = BatonFarm(
            payable(
                address(
                    batonFactory.createFarmFromExistingPairETH{ value: 10 ether }(owner, address(ethPair), weekDuration)
                )
            )
        );
        ethPairLpToken.approve(address(batonFarmAddressPairETH), 100 ether);

        batonFarmAddressPairNFT = BatonFarm(
            payable(
                address(
                    batonFactory.createFarmFromExistingPairNFT(
                        owner, address(bayc), tokenIds, weekDuration, address(ethPair), reservoirOracleMessages
                    )
                )
            )
        );

        ethPairLpToken.approve(address(batonFarmAddressPairNFT), 100 ether);

        vm.stopPrank();

        vm.label(babe, "babe");
        vm.label(address(caviar), "caviar");
        vm.label(address(bayc), "bayc");
        vm.label(address(usd), "usd");
        vm.label(address(weth), "weth");
        vm.label(address(ercPair), "ercPair");
        vm.label(address(ercPairLpToken), "ercPairLpToken");
        vm.label(address(ethPair), "ethPair");
        vm.label(address(ethPairLpToken), "ethPair-LP-token");
        vm.label(address(batonFactory), "baton-factory");
    }

    function migrateFarm(BatonFarm farm, address tester) internal {
        vm.startPrank(tester);
        farm.initiateMigration(address(0xbabe));
        vm.stopPrank();
        vm.startPrank(batonMonitor);
        farm.migrate();
        vm.stopPrank();
    }

    function setLPFee(BatonFactory batonFactory, uint256 bp) internal {
        vm.startPrank(batonMonitor);
        batonFactory.proposeNewLPFee(bp);
        assertEq(batonFactory.LPFeeProposalApprovalDate(), block.timestamp + 7 days);

        skip(8 days);

        batonFactory.setLPFeeRate();
        assertEq(batonFactory.batonLPFee(), bp);
        vm.stopPrank();
    }

    receive() external payable { }
}
