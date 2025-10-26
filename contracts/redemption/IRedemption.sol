// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Hashes} from "contracts/Hashes.sol";

/// @title Hashes Redemption Interface
/// @notice This interface defines the contract for managing the redemption of Hashes tokens
/// for ETH. The redemption process has three stages: PreRedemption (deposits only),
/// Redemption (active redemption period), and PostRedemption (final redemption period).
interface IRedemption {
    /// @notice Enumeration of redemption stages
    /// @param PreRedemption Initial stage where only ETH deposits are accepted
    /// @param Redemption Active redemption stage where users can redeem their Hashes tokens
    /// @param PostRedemption Final stage where remaining users can claim their redemption
    enum Stages {
        PreRedemption,
        Redemption,
        PostRedemption
    }

    /// @notice Thrown when an operation is attempted in the wrong stage
    error WrongStage();

    /// @notice Thrown when a transfer operation fails
    error TransferFailed();

    /// @notice Thrown when attempting to move to PostRedemption stage too early
    error MinRedemptionTime();

    /// @notice Emitted when ETH is deposited into the contract
    /// @param _user The address of the user who deposited ETH
    /// @param _amount The amount of ETH deposited
    event Deposit(address _user, uint256 _amount);

    /// @notice Emitted when a user redeems their Hashes tokens
    /// @param _user The address of the user who redeemed tokens
    /// @param _amount The amount of ETH received from redemption
    event Redeemed(address _user, uint256 _amount);

    /// @notice Emitted when the redemption stage is changed
    /// @param _stage The new stage that was set
    event StageSet(Stages _stage);

    /// @notice Allows users to deposit ETH into the contract
    /// @dev Can only be called during PreRedemption and Redemption stages
    /// @custom:throws WrongStage if called during PostRedemption stage
    function deposit() external payable;

    /// @notice Allows users to redeem their eligible Hashes tokens for ETH
    /// @dev Behavior depends on current stage:
    /// - PreRedemption: Reverts with WrongStage
    /// - Redemption: Claims first redemption amount
    /// - PostRedemption: Claims second redemption amount
    /// @custom:throws WrongStage if called during PreRedemption stage
    /// @custom:throws TransferFailed if ETH transfer fails
    function redeem() external;

    /// @notice Sets the contract to Redemption stage
    /// @dev Can only be called by owner during PreRedemption stage
    /// Calculates redemptionPerHash based on current contract balance
    /// @custom:throws WrongStage if not in PreRedemption stage
    /// @custom:throws OwnableUnauthorizedAccount if called by non-owner
    function setRedemptionStage() external;

    /// @notice Sets the contract to PostRedemption stage
    /// @dev Can only be called by owner during Redemption stage after minimum time has elapsed
    /// Recalculates redemptionPerHash based on actual redeemed tokens
    /// @custom:throws WrongStage if not in Redemption stage
    /// @custom:throws MinRedemptionTime if minimum redemption time has not elapsed
    /// @custom:throws OwnableUnauthorizedAccount if called by non-owner
    function setPostRedemptionStage() external;

    /// @notice Allows owner to recover ERC20 tokens sent to the contract
    /// @dev Transfers all tokens of the specified token to the owner
    /// @param _token The ERC20 token contract to recover
    /// @custom:throws OwnableUnauthorizedAccount if called by non-owner
    function recoverERC20(IERC20 _token) external;

    /// @notice Checks if a specific Hashes token is eligible for redemption
    /// @dev A token is eligible if:
    /// - Token ID is less than 1000
    /// - Token is not deactivated
    /// - Token is not in the excluded list
    /// @param _tokenId The token ID to check
    /// @return bool True if the token is eligible for redemption, false otherwise
    function isHashEligibleForRedemption(uint256 _tokenId) external view returns (bool);

    /// @notice Returns the Hashes NFT contract address
    /// @return Hashes The address of the Hashes contract
    function HASHES() external view returns (Hashes);

    /// @notice Returns the minimum time required before moving to PostRedemption stage
    /// @return uint256 The minimum redemption time in seconds (180 days)
    function MIN_REDEMPTION_TIME() external view returns (uint256);

    /// @notice Returns the total number of initially eligible Hashes tokens for redemption
    /// @return uint256 The total number of eligible tokens (520)
    function INITIAL_ELIGIBLE_HASHES_TOTAL() external view returns (uint256);

    /// @notice Returns the current stage of the redemption process
    /// @return Stages The current redemption stage
    function stage() external view returns (Stages);

    /// @notice Returns the timestamp when the Redemption stage was set
    /// @return uint256 The timestamp when redemption stage was activated
    function redemptionSetTime() external view returns (uint256);

    /// @notice Returns the amount of ETH per Hashes token for redemption
    /// @return uint256 The redemption amount per token in wei
    function redemptionPerHash() external view returns (uint256);

    /// @notice Returns the total number of Hashes tokens that have been redeemed
    /// @return uint256 The total count of redeemed tokens
    function totalNumberRedeemed() external view returns (uint256);

    /// @notice Returns the number of tokens redeemed by a specific user
    /// @param _user The user address to check
    /// @return uint256 The number of tokens redeemed by the user
    function amountRedeemed(address _user) external view returns (uint256);

    /// @notice Returns whether a specific token ID is excluded from redemption
    /// @param _tokenId The token ID to check
    /// @return bool True if the token is excluded, false otherwise
    function excludedHashIDs(uint256 _tokenId) external view returns (bool);
}
