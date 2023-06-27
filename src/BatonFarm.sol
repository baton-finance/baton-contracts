// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { Owned } from "solmate/auth/Owned.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC721, ERC721TokenReceiver } from "solmate/tokens/ERC721.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { Pair, ReservoirOracle } from "@caviar/src/Pair.sol";
import { BatonFactory } from "./BatonFactory.sol";

/// @title BatonFarm
/// @author Baton team
/// @notice Yield farms that allow for users to stake their NFT AMM LP positions into our yield farm
/// @dev We note that this implementation is coupled to Caviar's Pair contract. A Pair represents a
///      a Uniswap-V2-like CFMM pool consisting of fractions of the NFT (hence a Pair.nft() function).
contract BatonFarm is Pausable, Owned, ERC721TokenReceiver {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // caviar
    Pair public immutable pair;

    ERC20 public immutable rewardsToken; // token given as reward
    ERC20 public immutable stakingToken; // token being staked
    uint256 public periodFinish; // timestamp in which the farm is shutdown
    uint256 public rewardRate; // amount of fees given persecond
    uint256 public rewardsDuration; // duration in seconds that the rewards should be vested over
    uint256 public lastUpdateTime; // last time the reward was updated
    uint256 public rewardPerTokenStored;
    uint256 private _totalSupply; // total amount of staked assets

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards; // user -> rewards
    mapping(address => uint256) private _balances; // user -> staked assets

    /*//////////////////////////////////////////////////////////////
                    MIGRATION VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public migration; // address to migrate to
    bool public migrationComplete; // has a migration been initilized and completed

    address public rewardsDistributor; // an address who is capable of updating the pool with new rewards

    /*//////////////////////////////////////////////////////////////
                    BATON VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable batonMonitor; // this address is the only one who can complete a migration, propose and set
        // a new
        // farm fee.
    BatonFactory public immutable batonFactory;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RewardAdded(uint256 reward);
    event Received(address indexed user, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event MigrationInitiated(address migration);
    event MigrationComplete(address migration, uint256 amount, uint256 timestamp);
    event UpdateRewardsDistributor(address _rewardsDistributor);
    event UpdateRewardsDuration(uint256 newRewardsDuration);
    event Recovered(address tokenAddress, uint256 tokenAmount);
    event FoundSurplus(uint256 surplusAmount, address recoveredTo);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _owner,
        address _rewardsDistributor,
        address _batonMonitor,
        address _rewardsToken,
        address _pairAddress,
        uint256 _rewardsDuration, // in seconds
        address _batonFactory
    )
        Owned(_owner)
    {
        require(_owner != address(0), "_owner shouldnt be address(0)");
        require(_rewardsDistributor != address(0), "_rewardsDistributor shouldnt be address(0)");
        require(_batonMonitor != address(0), "_batonMonitor shouldnt be address(0)");
        require(_rewardsToken != address(0), "_rewardsToken shouldnt be address(0)");
        require(_pairAddress != address(0), "_pairAddress shouldnt be address(0)");
        require(_batonFactory != address(0), "_batonFactory shouldnt be address(0)");

        pair = Pair(_pairAddress);

        rewardsToken = ERC20(_rewardsToken);
        stakingToken = ERC20(address(pair.lpToken()));
        rewardsDistributor = _rewardsDistributor;

        require(_rewardsDuration > 0, "_rewardsDuration cannot be 0");
        require(_rewardsDuration < 5 * (365 days), "_rewardsDuration cannot be more then 5 years");
        rewardsDuration = _rewardsDuration;

        batonMonitor = _batonMonitor;
        batonFactory = BatonFactory(_batonFactory);

        ERC721(pair.nft()).setApprovalForAll(address(pair), true);
    }

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Calculates the percentage of an amount based on basis points.
     * @param basisPoints The basis points value (100bp == 1%).
     * @param amount The amount to calculate the percentage of.
     * @return The calculated percentage.
     */
    function calculatePercentage(uint256 basisPoints, uint256 amount) public pure returns (uint256) {
        uint256 percentage = basisPoints * amount / 10_000;
        return percentage;
    }

    /**
     * @dev Returns the last time at which the reward is applicable.
     * @return The last time reward is applicable (either the current block timestamp or the end of the reward period).
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @dev Returns the reward per token earned.
     * @return The calculated reward per token.
     */
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        uint256 lastTimeApplicable = lastTimeRewardApplicable();
        uint256 lastUpdateTimeDiff = lastTimeApplicable - lastUpdateTime;
        uint256 rewardRateMul = rewardRate * 1e18;
        uint256 rewardPerTokenIncrease = (lastUpdateTimeDiff * rewardRateMul) / _totalSupply;

        return rewardPerTokenStored + rewardPerTokenIncrease;
    }

    /**
     * @dev Returns the amount of rewards earned by an account.
     * @param account The address of the account.
     * @return The amount of rewards earned.
     */
    function earned(address account) public view returns (uint256) {
        uint256 rpt = rewardPerToken();
        uint256 userRewardPerTokenPaidDiff = rpt - userRewardPerTokenPaid[account];
        uint256 balanceOfAccount = _balances[account];
        uint256 reward = (balanceOfAccount * userRewardPerTokenPaidDiff) / 1e18;
        return reward + rewards[account];
    }

    /**
     * @dev Returns the unearned rewards amount.
     * @return The unearned rewards.
     */
    function _unearnedRewards() internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 remainingTime = periodFinish - currentTime;
        uint256 remainingRewards = rewardRate * remainingTime;

        return remainingRewards;
    }

    /*//////////////////////////////////////////////////////////////
                        STAKE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows the user to stake `amount` of the `stakingToken` into this farm
     * @param amount Amount to stake into the farm
     */
    function stake(uint256 amount) external poolNotMigrated onlyWhenPoolActive whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Helper function to 1) deposit equal parts of ETH and NFTs into the related
     *         Caviar NFT AMM pool for the user, 2) auto-staking the LP position into this
     *         contract by letting the contract hold custody of the position
     * @param tokenIds Given that this farm is present to a Caviar pair, ids of underlying NFT
     * @param minLpTokenAmount Minimum LP token amount as a means of slippage control
     * @param minPrice The minimum price of the pair.
     * @param maxPrice The maximum price of the pair.
     * @param deadline The deadline for the transaction.
     */
    function nftAddAndStake(
        uint256[] calldata tokenIds,
        uint256 minLpTokenAmount,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 deadline,
        bytes32[][] calldata proofs,
        ReservoirOracle.Message[] calldata messages
    )
        external
        payable
        onlyWhenPoolActive
        whenNotPaused
        poolNotMigrated
        updateReward(msg.sender)
    {
        // Retrieve the NFTs from the user
        for (uint256 i = 0; i < tokenIds.length; i++) {
            ERC721(pair.nft()).safeTransferFrom(msg.sender, address(this), tokenIds[i]);
        }

        // Deposit equal parts of ETH (msg.value) and NFTs into the Caviar NFT AMM pool
        uint256 lpTokenAmount = pair.nftAdd{ value: msg.value }(
            msg.value, tokenIds, minLpTokenAmount, minPrice, maxPrice, deadline, proofs, messages
        );

        require(lpTokenAmount > 0, "Cannot stake 0");

        // prevent a reentracny attack from `pair.nftAdd`, make sure that stakingToken.balanceOf is acctually updated
        require(
            stakingToken.balanceOf(address(this)) == _totalSupply + lpTokenAmount,
            "stakingToken balance didnt update from lpTokenAmount"
        );

        // Ensure that the LP amount isn't zilch and record in supply / user balance
        _totalSupply = _totalSupply + lpTokenAmount;
        _balances[msg.sender] = _balances[msg.sender] + lpTokenAmount;

        emit Staked(msg.sender, lpTokenAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAWING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraw Pair position from the contract, decomposed as the
     *         baseToken (e.g WETH) and fractionalised NFT tokens. NFTs are returned to the user.
     * @param amount Amount of the LP position to withdraw
     * @param minBaseTokenOutputAmount Min amount to get of the base token, accounting for slippage
     * @param deadline Deadline to retrieve position by
     * @param tokenIds NFT IDs to reddem from LP
     * @param withFee An optional unwrapping fee
     */
    function withdrawAndRemoveNftFromPool(
        uint256 amount,
        uint256 minBaseTokenOutputAmount,
        uint256 deadline,
        uint256[] calldata tokenIds,
        bool withFee
    )
        external
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= _balances[msg.sender], "Cannot withdraw more then you have staked");

        // remove the amount the user is unstaking
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;

        uint256 batonFeeAmount = calculatePercentage(batonFactory.batonLPFee(), amount); // calculate batons fee

        // if the fee is more then 0 send the fee to batonMonitor
        if (batonFeeAmount > 0) {
            stakingToken.safeTransfer(batonMonitor, batonFeeAmount);
        }

        uint256 amountToRemove = amount - batonFeeAmount;

        (uint256 baseTokenOutputAmount, uint256 fractionalTokenOutputAmount) =
            pair.nftRemove(amountToRemove, minBaseTokenOutputAmount, deadline, tokenIds, withFee);

        // transfer the base / fractional nft tokens to the user
        SafeTransferLib.safeTransferETH(msg.sender, baseTokenOutputAmount);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            ERC721(pair.nft()).safeTransferFrom(address(this), msg.sender, tokenIds[i]);
        }

        // send user his rewards
        harvest();

        // emit an event
        emit Withdrawn(msg.sender, amountToRemove);
    }

    /**
     * @notice Withdraw Pair position from the contract, decomposed as the
     *         baseToken (e.g WETH) and fractionalised NFT tokens
     * @param amount Amount of the LP position to withdraw
     * @param minBaseTokenOutputAmount Min amount to get of the base token, accounting for slippage
     * @param minFractionalTokenOutputAmount Min amount to get of fractional NFT, accounting for
     *                                       slippage
     * @param deadline Deadline to retrieve position by
     */
    function withdrawAndRemoveLPFromPool(
        uint256 amount,
        uint256 minBaseTokenOutputAmount,
        uint256 minFractionalTokenOutputAmount,
        uint256 deadline
    )
        external
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= _balances[msg.sender], "Cannot withdraw more then you have staked");

        // remove the amount the user is unstaking
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;

        // take fee from lptoken
        uint256 batonFeeAmount = calculatePercentage(batonFactory.batonLPFee(), amount); // calculate batons fee

        // if the fee is more then 0 send the fee to batonMonitor
        if (batonFeeAmount > 0) {
            stakingToken.safeTransfer(batonMonitor, batonFeeAmount);
        }

        uint256 amountToRemove = amount - batonFeeAmount;

        if (amountToRemove > 0) {
            // calculate the amount of base (eth for example) tokens and fractional nft tokens the user should receive
            (uint256 baseTokenOutputAmount, uint256 fractionalTokenOutputAmount) =
                pair.remove(amountToRemove, minBaseTokenOutputAmount, minFractionalTokenOutputAmount, deadline);

            // transfer the base / fractional nft tokens to the user
            SafeTransferLib.safeTransferETH(msg.sender, baseTokenOutputAmount);
            ERC20(address(pair)).safeTransfer(msg.sender, fractionalTokenOutputAmount);
        }

        // send user his rewards
        harvest();

        // emit an event
        emit Withdrawn(msg.sender, amountToRemove);
    }

    /**
     * @notice Withdraw staked tokens from the farm
     * @param amount Amount of the Pair position to withdraw
     */
    function withdraw(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= _balances[msg.sender], "Cannot withdraw more then you have staked");

        // remove the amount unstaked from the total balance
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;

        uint256 batonFeeAmount = calculatePercentage(batonFactory.batonLPFee(), amount); // calculate batons fee

        // if the fee is more then 0 send the fee to batonMonitor
        if (batonFeeAmount > 0) {
            stakingToken.safeTransfer(batonMonitor, batonFeeAmount);
        }

        uint256 amountToWithdrawal = amount - batonFeeAmount;

        // transfer the tokens to user
        if (amountToWithdrawal > 0) {
            stakingToken.safeTransfer(msg.sender, amountToWithdrawal);
        }

        emit Withdrawn(msg.sender, amountToWithdrawal);
    }

    /*//////////////////////////////////////////////////////////////
                              GET REWARDS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow a user to harvest the rewards accumulated up until this point
     * @notice If a fee is set then the contract will reduct the fee from the total sent to the fuction caller.
     */
    function harvest() public updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender]; // get users earned fees
        uint256 batonFeeAmount = calculatePercentage(batonFactory.batonRewardsFee(), reward); // calculate batons fee

        rewards[msg.sender] = 0; // clear the reward counter for the user

        // if the fee is more then 0 send the fee to batonMonitor
        if (batonFeeAmount > 0) {
            rewardsToken.safeTransfer(batonMonitor, batonFeeAmount);
        }

        uint256 amountToReward = reward - batonFeeAmount;

        if (amountToReward > 0) {
            // send the reward
            rewardsToken.safeTransfer(msg.sender, amountToReward);
        }

        // emit an event
        emit RewardPaid(msg.sender, amountToReward);
    }

    /**
     * @notice Withdraws staked tokens and harvests earned rewards in a single transaction.
     * @dev Calls both `withdraw` and `harvest` functions for the caller.
     */
    function withdrawAndHarvest() external {
        withdraw(_balances[msg.sender]);
        harvest();
    }

    /*//////////////////////////////////////////////////////////////
                           MIGRATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates the migration process by setting the migration target.
     * @dev Only callable by the contract owner when the pool is active.
     * @param _migration The address of the new contract to migrate to.
     */
    function initiateMigration(address _migration) external onlyOwner poolNotMigrated {
        require(_migration != address(0), "Please migrate to a valid address");
        require(_migration != address(this), "Cannot migrate to self");

        migration = _migration;

        // emit an event
        emit MigrationInitiated(_migration);
    }

    /**
     * @notice Migrates the unearned rewards to the new contract.
     * @dev Only callable by the BatonMonitor address when in migration mode and the pool is active.
     */
    function migrate() external onlyBatonMonitor inMigrationMode poolNotMigrated onlyWhenPoolActive {
        // calculate staking rewards still not rewarded
        uint256 rewardsToMigrate = _unearnedRewards();

        // complete migration
        migrationComplete = true;
        // stop farm
        periodFinish = block.timestamp;

        // transfer these rewards to the migration address.
        rewardsToken.safeTransfer(address(migration), rewardsToMigrate);

        // emit an event
        emit MigrationComplete(migration, rewardsToMigrate, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            NOTIFY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Given a reward amount calculate the rewardRate per second
     * @notice Other fees may be incurred due to token spesific fees (some tokens may take a fee on transferFrom).
     * @dev Only callable by the rewards distributor or the contract owner. Updates the rewards state.
     *         This function should be called every time new rewards are added to the farm.
     * @param reward The amount of reward to be distributed.
     */
    function notifyRewardAmount(uint256 reward)
        external
        onlyRewardsDistributor
        poolNotMigrated
        updateReward(address(0))
    {
        require(reward > 0, "reward cannot be 0");
        rewardsToken.transferFrom(msg.sender, address(this), reward);

        uint256 surplusAmount = 0;
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
            periodFinish = block.timestamp + rewardsDuration;

            surplusAmount = reward - (rewardRate * rewardsDuration);
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / remaining;

            surplusAmount = (reward + leftover) - (rewardRate * remaining);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        require(rewardRate > 0, "reward rate = 0");
        require(rewardRate * rewardsDuration <= rewardsToken.balanceOf(address(this)), "Provided reward too high");

        // check for surplus, if it exist send back to rewards distributor
        if (surplusAmount != 0) {
            rewardsToken.safeTransfer(rewardsDistributor, surplusAmount);
            emit FoundSurplus(surplusAmount, rewardsDistributor);
        }

        lastUpdateTime = block.timestamp;
        emit RewardAdded(reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        require(tokenAddress != address(rewardsToken), "Cannot withdraw the reward token");

        ERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /**
     * @notice Sets the address of the rewards distributor.
     * @dev Only callable by the contract owner.
     * @param _rewardsDistributor The address of the new rewards distributor.
     */
    function setRewardsDistributor(address _rewardsDistributor) external onlyOwner {
        require(_rewardsDistributor != address(0), "_rewardsDistributor cannot be address(0)");
        rewardsDistributor = _rewardsDistributor;

        emit UpdateRewardsDistributor(_rewardsDistributor);
    }

    /**
     * @notice Update the rewardsDuration.
     * @dev Only callable by the contract owner.
     * @param _rewardsDuration The new rewardsDuration
     */
    function setRewardsDuration(uint256 _rewardsDuration) public onlyOwner {
        require(block.timestamp >= periodFinish, "pool is running, cannot update the duration");
        rewardsDuration = _rewardsDuration;

        emit UpdateRewardsDuration(rewardsDuration);
    }

    /**
     * @notice pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== MODIFIERS ========== */

    /**
     * @notice Modifier to update the rewards state before executing a function.
     * @dev Updates rewardPerTokenStored, lastUpdateTime, rewards[account], and userRewardPerTokenPaid[account].
     * @param account The address of the account for which to update the rewards state.
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /**
     * @notice Modifier to ensure that only the rewards distributor or contract owner can call a function.
     * @dev Requires that the caller is either the rewards distributor or the contract owner.
     */
    modifier onlyRewardsDistributor() {
        require(msg.sender == rewardsDistributor || msg.sender == owner, "Caller is not RewardsDistributor contract");
        _;
    }

    /**
     * @notice Modifier to ensure that only the BatonMonitor contract can call a function.
     * @dev Requires that the caller is the BatonMonitor contract.
     */
    modifier onlyBatonMonitor() {
        require(msg.sender == batonMonitor, "Caller is not BatonMonitor contract");
        _;
    }

    /**
     * @notice Modifier to ensure that the contract is in migration mode.
     * @dev Requires that the migration address is not the zero address.
     */
    modifier inMigrationMode() {
        require(migration != address(0), "Contract owner must first call initiateMigration()");
        _;
    }

    /**
     * @notice Modifier to ensure that the pool is still active before calling a function.
     * @dev Requires that the migration has not been completed.
     */
    modifier poolNotMigrated() {
        require(!migrationComplete, "This contract has been migrated, you cannot deposit new funds.");
        _;
    }

    /**
     * @notice Modifier to ensure that the pool is active.
     * @dev Requires that block.timestamp < periodFinish
     */
    modifier onlyWhenPoolActive() {
        require(block.timestamp < periodFinish, "This farm is not active");
        _;
    }

    /**
     * @notice Modifier to ensure that the pool is still active before calling a function.
     * @dev Requires that the migration has not been completed.
     */
    modifier onlyWhenPoolOver() {
        require(block.timestamp >= periodFinish, "This farm is still active");
        _;
    }
}
