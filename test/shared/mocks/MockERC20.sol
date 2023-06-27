// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_, decimals_) { }
}
