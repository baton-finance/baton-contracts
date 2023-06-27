// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IWETH9 } from "../../../src/IWETH9.sol";

/**
 * @title WETH9
 * @author Dapphub
 * @notice [Wrapped Ether](https://weth.io/) smart contract. Extends **ERC20**.
 */
contract MockWETH is IWETH9, ERC20 {
    /**
     * @notice Constructs the **WETH** contract.
     */
    constructor() ERC20("Wrapped Ether", "WETH") { }

    /**
     * @notice Wraps Ether. **WETH** will be minted to the sender at 1 **ETH** : 1 **WETH**.
     */
    receive() external payable override {
        deposit();
    }

    /**
     * @notice Wraps Ether. **WETH** will be minted to the sender at 1 **ETH** : 1 **WETH**.
     */
    fallback() external payable override {
        deposit();
    }

    /**
     * @notice Wraps Ether. **WETH** will be minted to the sender at 1 **ETH** : 1 **WETH**.
     */
    function deposit() public payable override {
        _mint(msg.sender, msg.value);
    }

    /**
     * @notice Unwraps Ether. **ETH** will be returned to the sender at 1 **ETH** : 1 **WETH**.
     * @param wad Amount to unwrap.
     */
    function withdraw(uint256 wad) public override {
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
}
