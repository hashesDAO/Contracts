// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Hashes} from "contracts/Hashes.sol";
import {IRedemption} from "contracts/redemption/IRedemption.sol";

contract Redemption is IRedemption, Ownable, ReentrancyGuard {
    Hashes public constant HASHES = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);

    uint256 public constant MIN_REDEMPTION_TIME = 180 days;

    uint256 public constant INITIAL_ELIGIBLE_HASHES_TOTAL = 520;

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
        emit StageSet(stage);
    }

    receive() external payable {
        _deposit();
    }

    function deposit() external payable {
        _deposit();
    }

    function _deposit() internal nonReentrant {
        if (stage == Stages.PostRedemption) revert WrongStage();
        emit Deposit(msg.sender, msg.value);
    }

    function redeem() external nonReentrant {
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

    function setRedemptionStage() external onlyOwner nonReentrant {
        if (stage != Stages.PreRedemption) revert WrongStage();
        stage = Stages.Redemption;
        redemptionSetTime = block.timestamp;
        redemptionPerHash = address(this).balance / INITIAL_ELIGIBLE_HASHES_TOTAL;
        emit StageSet(stage);
    }

    function setPostRedemptionStage() external onlyOwner nonReentrant {
        if (stage != Stages.Redemption) revert WrongStage();
        if (block.timestamp < redemptionSetTime + MIN_REDEMPTION_TIME) revert MinRedemptionTime();
        stage = Stages.PostRedemption;
        redemptionPerHash = address(this).balance / totalNumberRedeemed;
        emit StageSet(stage);
    }

    function recoverERC20(IERC20 _token) external onlyOwner nonReentrant {
        _token.transfer(msg.sender, _token.balanceOf(msg.sender));
    }

    function isHashEligibleForRedemption(uint256 _tokenId) public view returns (bool) {
        if (_tokenId >= 1000) return false;
        if (HASHES.deactivated(_tokenId)) return false;
        if (excludedHashIDs[_tokenId]) return false;
        return true;
    }
}
