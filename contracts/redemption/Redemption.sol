// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Hashes} from "contracts/Hashes.sol";
import {IRedemption} from "contracts/redemption/IRedemption.sol";

contract Redemption is IRedemption, Ownable, ReentrancyGuard {
    Hashes public constant HASHES = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);

    uint256 public constant MIN_REDEMPTION_TIME = 180 days;

    uint256 public constant INITIAL_ELIGIBLE_HASHES_TOTAL = 818;

    Stages public stage;

    uint256 public redemptionSetTime;

    uint256 public redemptionPerHash;

    uint256 public totalNumberRedeemed;

    mapping(address => uint256) public amountRedeemed;

    mapping(uint256 => bool) public excludedHashIDs;

    constructor(uint256[] memory _excludedIds, address _owner) {
        _transferOwnership(_owner);
        stage = Stages.PreRedemption;
        uint256 length = _excludedIds.length;
        for (uint256 i; i < length; i++) {
            excludedHashIDs[_excludedIds[i]] = true;
        }
    }

    receive() external payable {}

    function redeem() external nonReentrant {
        if (stage == Stages.PreRedemption) {
            revert WrongStage();
        } else if (stage == Stages.Redemption) {
            uint256 balance = HASHES.balanceOf(msg.sender);
            uint256 tokenId;
            uint256 counter;
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
        } else if (stage == Stages.PostRedemption) {
            uint256 amount = amountRedeemed[msg.sender];
            amountRedeemed[msg.sender] = 0;
            (bool success,) = address(msg.sender).call{value: amount * redemptionPerHash}("");
            if (!success) revert TransferFailed();
        }
    }

    function setRedemptionStage() external onlyOwner nonReentrant {
        if (stage != Stages.PreRedemption) revert WrongStage();
        stage = Stages.Redemption;
        redemptionSetTime = block.timestamp;
        uint256 balance = address(this).balance;
        redemptionPerHash = balance / INITIAL_ELIGIBLE_HASHES_TOTAL;
    }

    function setPostRedemptionStage() external onlyOwner nonReentrant {
        if (stage != Stages.Redemption) revert WrongStage();
        if (block.timestamp < redemptionSetTime + MIN_REDEMPTION_TIME) revert MinRedemptionTime();
        stage = Stages.PostRedemption;
        uint256 balance = address(this).balance;
        redemptionPerHash = balance / totalNumberRedeemed;
    }

    function isHashEligibleForRedemption(uint256 _tokenId) public view returns (bool) {
        if (_tokenId >= 1000) return false;
        if (HASHES.deactivated(_tokenId)) return false;
        if (excludedHashIDs[_tokenId]) return false;
        return true;
    }
}
