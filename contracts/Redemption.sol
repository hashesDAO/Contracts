// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Hashes} from "./Hashes.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * ToDo
 * Tests
 * Nat spec
 */
contract Redemption is Ownable, ReentrancyGuard {
    enum Stages {
        PreRedemption,
        Redemption,
        PostRedemption
    }

    /// CONSTANTS ///

    ERC20 public constant WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Hashes public constant HASHES = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);
    uint256 public constant MINDEPOSITAMOUNT = 100;
    uint256 public constant MINCLAIMAMOUNT = 1;
    uint256 public constant NUMBEROFELIGIBLEHASHES = 831; /// @dev double check before deploying
    uint256 public constant MINREDEMPTIONTIME = 500 days;

    /// VARIABLES ///

    Stages public stage;

    uint256 public redemptionSetTime;
    /// @dev initial pro rata redemption
    uint256 public redemptionPerHash;
    /// @dev claim remaining funds
    uint256 public postRedemptionPerHash;
    uint256 public totalNumberRedeemed;
    
    mapping(address => uint256) public amountRedeemed;
    mapping(address => bool) public postRedemptionClaimed;

    /// CONSTRUCTOR ///

    constructor(address _redemptionMultiSig) {
        _transferOwnership(_redemptionMultiSig);
        stage = Stages.PreRedemption;
    }

    /// EXTERNALS ///

    receive() external payable {
        revert();
    }

    /// @dev Owner of Hashes must approve contract to move Hashes
    function redeemHashes(uint256[] calldata _tokenIds) external nonReentrant {
        require(stage == Stages.Redemption, "Redemption: Must be in redemption stage");

        uint256 length = _tokenIds.length;

        require(length > 0, "Redemption: Must redeem more than zero Hashes");

        uint256 tokenId;

        for (uint256 i; i < length; i++) {
            tokenId = _tokenIds[i];

            require(
                isHashEligibleForRedemption(tokenId), 
                string(abi.encodePacked('Redemption: Hash at index #', Strings.toString(i), ' is ineligible'))
            );

            HASHES.transferFrom(msg.sender, address(this), tokenId);
        }

        amountRedeemed[msg.sender] += length;
        totalNumberRedeemed += length;

        WETH.transfer(msg.sender, redemptionPerHash * length);
    }

    function redeemRemaining() external nonReentrant {
        require(stage == Stages.PostRedemption, "Redemption: Must be in post-redemption stage");
        require(amountRedeemed[msg.sender] > 0, "Redemption: User did not redeem any hashes during initial redeem period");
        require(!postRedemptionClaimed[msg.sender], "Redemption: User has already claimed post-redemption amount");

        postRedemptionClaimed[msg.sender] = true;

        WETH.transfer(msg.sender, postRedemptionPerHash);
    }

    /// OWNER ONLY ///

    /// @dev Multisig owner must grant contract permission to move WETH
    function depositAndEnableRedemptions(uint256 _amount) external onlyOwner nonReentrant {
        require(stage == Stages.PreRedemption, "Redemption: Must be in pre-redemption stage");
        require(_amount > MINDEPOSITAMOUNT * WETH.decimals(), "Redemption: Must deposit at least 100 WETH");

        WETH.transfer(address(this), _amount);

        redemptionPerHash = WETH.balanceOf(address(this)) / NUMBEROFELIGIBLEHASHES;

        redemptionSetTime = block.timestamp;

        stage = Stages.Redemption;
    }

    function setPostRedemptionStage() external onlyOwner nonReentrant {
        require(stage == Stages.Redemption, "Redemption: Must be in redemption stage");
        require(block.timestamp > redemptionSetTime + MINREDEMPTIONTIME, "Redemption: Min redemption time has not elapsed");
        require(totalNumberRedeemed > 0, "Redemption: Nothing has been redeemed");
        
        uint256 wETHBalance = WETH.balanceOf(address(this));
        
        require(wETHBalance > MINCLAIMAMOUNT * WETH.decimals(), "Redemption: Contract does not contain min claim amount");

        postRedemptionPerHash = wETHBalance / totalNumberRedeemed;

        stage = Stages.PostRedemption;
    }

    /// VIEWS ///

    function isHashEligibleForRedemption(uint256 _tokenId) public view returns (bool) {
        if (_tokenId >= 1000) return false; /// Non-DAO hash
        if (_tokenId < 100) return false; /// Dex Labs hash
        if (HASHES.deactivated(_tokenId)) return false; /// deactivated hash

        /*
        if (
            _tokenId == x ||
            _tokenId == y ||
        ) return false; /// Bought-back hashes
        */
        /// messy logic to exclude the bought-back hashes individually but I can't think of a better 
        /// way beyond trust or kintsugi burning them

        return true;
    } 
}