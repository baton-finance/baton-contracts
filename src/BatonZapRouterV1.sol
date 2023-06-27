// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// ReentrancyGuard
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { CaviarZapRouter } from "@caviar/src/CaviarZapRouter.sol";
import { Pair } from "@caviar/src/Pair.sol";
import { IWETH9 } from "./IWETH9.sol";
import { BatonFarm } from "./BatonFarm.sol";

/*
 * @author Inspiration from the work of Zapper and Beefy.
 */
contract BatonZapRouterV1 {
    using SafeTransferLib for address;

    function zapInETH(address payable farm, CaviarZapRouter.BuyParams calldata buyParams, CaviarZapRouter.AddParams calldata addParams) public payable {
        BatonFarm farm = BatonFarm(farm);
        Pair pair = Pair(farm.pair());

        // buy some fractional tokens
        pair.buy{value: buyParams.maxInputAmount}(
            buyParams.outputAmount, buyParams.maxInputAmount, buyParams.deadline
        );

        // add fractional tokens and eth
        uint256 lpTokenAmount = pair.add{value: address(this).balance}(
            addParams.baseTokenAmount,
            addParams.fractionalTokenAmount,
            addParams.minLpTokenAmount,
            addParams.minPrice,
            addParams.maxPrice,
            addParams.deadline
        );

        pair.lpToken().transfer(msg.sender, lpTokenAmount);
    }
}
