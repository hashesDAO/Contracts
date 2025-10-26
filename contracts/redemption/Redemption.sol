// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Hashes} from "contracts/Hashes.sol";
import {IRedemption} from "contracts/redemption/IRedemption.sol";

/// @title Redemption
/// @notice Manages the redemption of Hashes tokens for ETH
/// @dev This contract implements a three-stage redemption system for Hashes tokens.
/// Users can deposit ETH during PreRedemption stage, redeem their eligible Hashes tokens
/// during Redemption stage, and claim remaining redemptions during PostRedemption stage.
contract Redemption is IRedemption, Ownable, ReentrancyGuard {
    /// @inheritdoc IRedemption
    Hashes public constant override HASHES = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);

    /// @inheritdoc IRedemption
    uint256 public constant override MIN_REDEMPTION_TIME = 180 days;

    /// @inheritdoc IRedemption
    uint256 public constant override INITIAL_ELIGIBLE_HASHES_TOTAL = 520;

    /// @inheritdoc IRedemption
    Stages public override stage;

    /// @inheritdoc IRedemption
    uint256 public override redemptionSetTime;

    /// @inheritdoc IRedemption
    uint256 public override redemptionPerHash;

    /// @inheritdoc IRedemption
    uint256 public override totalNumberRedeemed;

    /// @inheritdoc IRedemption
    mapping(address => uint256) public override amountRedeemed;

    /// @inheritdoc IRedemption
    mapping(uint256 => bool) public override excludedHashIDs;

    /// @notice Constructor initializes the redemption contract with excluded token IDs and sets the owner
    /// @param _excludedIds Array of token IDs that are excluded from redemption
    /// @param _owner Address that will be set as the contract owner
    constructor(uint256[] memory _excludedIds, address _owner) {
        _transferOwnership(_owner);
        stage = Stages.PreRedemption;
        uint256 length = _excludedIds.length;
        for (uint256 i; i < length; i++) {
            excludedHashIDs[_excludedIds[i]] = true;
        }
        emit StageSet(stage);
    }

    /// @notice Receive function for accepting ETH deposits
    receive() external payable {
        _deposit();
    }

    /// @inheritdoc IRedemption
    function deposit() external payable override {
        _deposit();
    }

    /// @notice Internal function to handle ETH deposits
    /// @dev Reverts if called during PostRedemption stage and emits Deposit event
    /// @custom:throws WrongStage if called during PostRedemption stage
    function _deposit() internal nonReentrant {
        if (stage == Stages.PostRedemption) revert WrongStage();
        emit Deposit(msg.sender, msg.value);
    }

    /// @inheritdoc IRedemption
    function redeem() external override nonReentrant {
        if (stage == Stages.PreRedemption) {
            revert WrongStage();
        } else if (stage == Stages.Redemption) {
            uint256 tokenId;
            uint256 counter;
            uint256 balance = HASHES.balanceOf(msg.sender);
            for (uint256 i; i < balance; i++) {
                tokenId = HASHES.tokenOfOwnerByIndex(msg.sender, i);
                if (isHashEligibleForRedemption(tokenId)) {
                    excludedHashIDs[tokenId] = true;
                    counter++;
                }
            }
            totalNumberRedeemed += counter;
            amountRedeemed[msg.sender] += counter;
            (bool success,) = address(msg.sender).call{value: counter * redemptionPerHash}("");
            if (!success) revert TransferFailed();
            emit Redeemed(msg.sender, counter * redemptionPerHash);
        } else if (stage == Stages.PostRedemption) {
            uint256 amount = amountRedeemed[msg.sender];
            amountRedeemed[msg.sender] = 0;
            (bool success,) = address(msg.sender).call{value: amount * redemptionPerHash}("");
            if (!success) revert TransferFailed();
            emit Redeemed(msg.sender, amount * redemptionPerHash);
        }
    }

    /// @inheritdoc IRedemption
    function setRedemptionStage() external override onlyOwner nonReentrant {
        if (stage != Stages.PreRedemption) revert WrongStage();
        stage = Stages.Redemption;
        redemptionSetTime = block.timestamp;
        redemptionPerHash = address(this).balance / INITIAL_ELIGIBLE_HASHES_TOTAL;
        emit StageSet(stage);
    }

    /// @inheritdoc IRedemption
    function setPostRedemptionStage() external override onlyOwner nonReentrant {
        if (stage != Stages.Redemption) revert WrongStage();
        if (block.timestamp < redemptionSetTime + MIN_REDEMPTION_TIME) revert MinRedemptionTime();
        stage = Stages.PostRedemption;
        redemptionPerHash = address(this).balance / totalNumberRedeemed;
        emit StageSet(stage);
    }

    /// @inheritdoc IRedemption
    function recoverERC20(IERC20 _token) external override onlyOwner nonReentrant {
        _token.transfer(msg.sender, _token.balanceOf(msg.sender));
    }

    /// @inheritdoc IRedemption
    function isHashEligibleForRedemption(uint256 _tokenId) public view override returns (bool) {
        if (_tokenId >= 1000) return false;
        if (HASHES.deactivated(_tokenId)) return false;
        if (excludedHashIDs[_tokenId]) return false;
        return true;
    }
}
