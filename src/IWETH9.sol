// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IWETH9
 * @author Dapphub
 * @notice [Wrapped Ether](https://weth.io/) smart contract. Extends **ERC20**.
 */
interface IWETH9 is IERC20Metadata {
    /// @notice Emitted when **ETH** is wrapped.
    event Deposit(address indexed dst, uint256 wad);
    /// @notice Emitted when **ETH** is unwrapped.
    event Withdrawal(address indexed src, uint256 wad);

    /**
     * @notice Wraps Ether. **WETH** will be minted to the sender at 1 **ETH** : 1 **WETH**.
     */
    receive() external payable;

    /**
     * @notice Wraps Ether. **WETH** will be minted to the sender at 1 **ETH** : 1 **WETH**.
     */
    fallback() external payable;

    /**
     * @notice Wraps Ether. **WETH** will be minted to the sender at 1 **ETH** : 1 **WETH**.
     */
    function deposit() external payable;

    /**
     * @notice Unwraps Ether. **ETH** will be returned to the sender at 1 **ETH** : 1 **WETH**.
     * @param wad Amount to unwrap.
     */
    function withdraw(uint256 wad) external;
}
