// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { BatonFarm } from "./BatonFarm.sol";
import { IWETH9 } from "./IWETH9.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { Caviar } from "@caviar/src/Caviar.sol";
import { Pair, ReservoirOracle } from "@caviar/src/Pair.sol";

/// @title BatonFactory
/// @author Baton team
/// @notice Factory contract for creating new BatonFarm contract instances
contract BatonFactory {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;
    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    enum Type {
        ETH,
        ERC20,
        NFT
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IWETH9 public weth;
    Caviar public caviar;
    address public batonMonitor;

    /*//////////////////////////////////////////////////////////////
                    FEE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public batonRewardsFee;
    uint256 public proposedRewardsFee;
    uint256 public rewardsFeeProposalApprovalDate;

    uint256 public batonLPFee;
    uint256 public proposedLPFee;
    uint256 public LPFeeProposalApprovalDate;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FarmCreated(
        address farmAddress,
        address owner,
        address rewardsDistributor,
        address rewardsToken,
        address pairAddress,
        uint256 rewardsDuration,
        Type farmType
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address payable _weth, address _caviar, address _batonMonitor) {
        weth = IWETH9(_weth);
        caviar = Caviar(_caviar);
        batonMonitor = _batonMonitor;
    }

    /*//////////////////////////////////////////////////////////////
                        MANAGE FEES FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Propose a new fee
     * @param _proposedLPFee The proposed fee in basis points (100 bp = 1%)
     * @dev Only callable by the BatonMonitor.
     */
    function proposeNewLPFee(uint256 _proposedLPFee) external onlyBatonMonitor {
        require(_proposedLPFee <= 25 * 100, "must: _proposedLPFee <= 2500 bp");

        proposedLPFee = _proposedLPFee;
        LPFeeProposalApprovalDate = block.timestamp + 7 days;
    }

    /**
     * @notice Set the fee to the latest proposed fee if 7 days have passed from proposal
     * @notice Revert if the date of proposal approval has not arrived
     * @dev Only callable by the BatonMonitor.
     */
    function setLPFeeRate() external onlyBatonMonitor {
        require(LPFeeProposalApprovalDate != 0, "no fee proposal");
        require(LPFeeProposalApprovalDate < block.timestamp, "must: LPFeeProposalApprovalDate < block.timestamp");

        batonLPFee = proposedLPFee;
        LPFeeProposalApprovalDate = 0;
    }

    /**
     * @notice Propose a new fee
     * @param _proposedRewardsFee The proposed fee in basis points (100 bp = 1%)
     * @dev Only callable by the BatonMonitor.
     */
    function proposeNewRewardsFee(uint256 _proposedRewardsFee) external onlyBatonMonitor {
        require(_proposedRewardsFee <= 25 * 100, "must: _proposedRewardsFee <= 2500 bp");

        proposedRewardsFee = _proposedRewardsFee;
        rewardsFeeProposalApprovalDate = block.timestamp + 7 days;
    }

    /**
     * @notice Set the fee to the latest proposed fee if 7 days have passed from proposal
     * @notice Revert if the date of proposal approval has not arrived
     * @dev Only callable by the BatonMonitor.
     */
    function setRewardsFeeRate() external onlyBatonMonitor {
        require(rewardsFeeProposalApprovalDate != 0, "no fee proposal");
        require(
            rewardsFeeProposalApprovalDate < block.timestamp, "must: rewardsFeeProposalApprovalDate < block.timestamp"
        );

        batonRewardsFee = proposedRewardsFee;
        rewardsFeeProposalApprovalDate = 0;
    }

    /*//////////////////////////////////////////////////////////////
                              CREATE FARMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates an instance of BatonFarm, incentivising staking with ERC20 rewards
    /// @param _owner Owner of the farm
    /// @param _rewardsToken Address of the rewards token
    /// @param _rewardAmount Amount of the rewards token to initially bootstrap the pool with
    /// @param _pairAddress Address of the underlying staking pair
    /// @param _rewardsDuration Duration that the rewards should be vested over
    /// @return Address of the newly-created BatonFarm contract instance
    function createFarmFromExistingPairERC20(
        address _owner,
        address _rewardsToken,
        uint256 _rewardAmount,
        address _pairAddress,
        uint256 _rewardsDuration
    )
        external
        returns (address)
    {
        require(_rewardAmount > 0, "expected _rewardAmount > 0");
        // create farm
        BatonFarm farm =
        new BatonFarm(_owner, address(this), batonMonitor, _rewardsToken, _pairAddress, _rewardsDuration, address(this));

        // fund the farm with reward tokens
        ERC20 rewardsToken = ERC20(_rewardsToken);
        rewardsToken.safeTransferFrom(msg.sender, address(this), _rewardAmount);

        rewardsToken.approve(address(farm), _rewardAmount);
        // update farm with new rewards
        farm.notifyRewardAmount(_rewardAmount);

        // Emit event
        emit FarmCreated(
            address(farm), _owner, address(this), _rewardsToken, _pairAddress, _rewardsDuration, Type.ERC20
        );

        // Return address of the farm
        return address(farm);
    }

    /// @notice Creates an instance of BatonFarm, incentivising staking with ETH rewards
    /// @param _owner Owner of the farm
    /// @param _pairAddress Address of the underlying staking pair
    /// @param _rewardsDuration Duration that the rewards should be vested over
    /// @return Address of the newly-created BatonFarm contract instance
    /// @dev This is very much `createFarmFromExistingPairERC20` but with ETH
    function createFarmFromExistingPairETH(
        address _owner,
        address _pairAddress,
        uint256 _rewardsDuration
    )
        external
        payable
        returns (address)
    {
        require(msg.value > 0, "expected msg.value > 0");
        // deposit sent ETH into weth
        weth.deposit{ value: msg.value }();

        // create farm with WETH as reward
        BatonFarm farm =
        new BatonFarm(_owner, address(this), batonMonitor, address(weth), _pairAddress, _rewardsDuration, address(this));

        // transfer WETH into farm
        weth.approve(address(farm), msg.value);

        // update farm with new rewards
        farm.notifyRewardAmount(msg.value);

        //emit event
        emit FarmCreated(address(farm), _owner, address(this), address(weth), _pairAddress, _rewardsDuration, Type.ETH);

        // return address of the farm
        return address(farm);
    }

    /// @notice Creates an instance of BatonFarm, incentivising staking with fractional NFT rewards
    /// @param _owner Owner of the farm
    /// @param _rewardsNFT  Address of the NFT to be given as rewards once fractionalised
    /// @param _rewardsTokenIds IDs of the NFT to retrieve from the msg.sender
    /// @param _rewardsDuration Duration that the rewards should be vested over
    /// @param _oracleMessages Messages from Reservoir to send to Caviar for getting fractional amount
    /// @param _pairAddress Address of the underlying staking pair
    /// @return Address of the newly-created BatonFarm contract instance
    /// @dev This is very much `createFarmFromExistingPairERC20` but with fractional NFTs from Caviar
    function createFarmFromExistingPairNFT(
        address _owner,
        address _rewardsNFT,
        uint256[] calldata _rewardsTokenIds,
        uint256 _rewardsDuration,
        address _pairAddress,
        ReservoirOracle.Message[] calldata _oracleMessages
    )
        external
        returns (address)
    {
        ERC721 rewardsNFT = ERC721(_rewardsNFT);

        require(_rewardsTokenIds.length > 0, "expected _rewardsTokenIds.length > 0");
        // transfer all nfts to this contract
        for (uint256 i = 0; i < _rewardsTokenIds.length; i++) {
            rewardsNFT.transferFrom(msg.sender, address(this), _rewardsTokenIds[i]);
        }

        // Fractionalise via Caviar
        Pair pair = Pair(caviar.pairs(_rewardsNFT, address(0), bytes32(0)));
        rewardsNFT.setApprovalForAll(address(pair), true);

        // Get fractional token amounts that will be the rewards for staking
        bytes32[][] memory proof = new bytes32[][](0);
        uint256 fractionalTokenAmount = pair.wrap(_rewardsTokenIds, proof, _oracleMessages);

        // Create a new farm
        BatonFarm farm =
        new BatonFarm(_owner, address(this), batonMonitor, address(pair), _pairAddress, _rewardsDuration, address(this));

        // Deposit the fractionalised-NFT rewards into the farm
        ERC20(address(pair)).safeTransfer(address(this), fractionalTokenAmount);

        ERC20(address(pair)).approve(address(farm), fractionalTokenAmount);
        farm.notifyRewardAmount(fractionalTokenAmount);

        // Emit event
        emit FarmCreated(address(farm), _owner, address(this), address(pair), _pairAddress, _rewardsDuration, Type.NFT);

        // Return address of the farm
        return address(farm);
    }

    /* ========== MODIFIERS ========== */

    /**
     * @notice Modifier to ensure that only the BatonMonitor contract can call a function.
     * @dev Requires that the caller is the BatonMonitor contract.
     */
    modifier onlyBatonMonitor() {
        require(msg.sender == batonMonitor, "Caller is not BatonMonitor contract");
        _;
    }
}
