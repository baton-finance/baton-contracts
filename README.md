# 👋 Baton

Baton is a yield farming protocol for NFT AMMs. It allows users to stake their NFT AMM LP positions and earn rewards.
Projects can use Baton to incentivize liquidity provision for their NFTs by creating new yield farms and depositing
rewards. They can deposit NFTs, ERC20s, or ETH as rewards. NFTs are fractionalized on caviar and deposited as ERC20s.
ETH is wrapped as WETH. And ERC20s are deposited directly.

There exists a demo app on goerli here: https://goerli.baton.finance/

For the staking calculations, we use the industry standard of amortizing the reward states. A video explaining can be
found [here](https://www.youtube.com/watch?v=b7F9q9Jsfvw), a well known small example implementation
[here](https://solidity-by-example.org/defi/staking-rewards/), and a production implementation made by Synthetix
[here](https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol).

## Setting up a development environment

- install [foundry](https://book.getfoundry.sh/getting-started/installation)
- run `pnpm i`
- run `forge install`
- to run test call `forge test` or `forge test --watch -vvv`

## Contracts overview

| Contract         | LOC | Description                                                                                 |
| ---------------- | --- | ------------------------------------------------------------------------------------------- |
| BatonFarm.sol    | 474 | A yield farming platform that allows users to stake NFT AMM LP positions and earn rewards   |
| BatonFactory.sol | 183 | A factory for creating BatonFarms with different reward types (ERC20, ETH, fractional NFTs) |
