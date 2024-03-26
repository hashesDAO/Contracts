// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Hashes} from "./Hashes.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Hashes Redemption 
/// @author Cooki
/// @notice This contract implements a staged redemption process for the Hashes DAO. Eligible DAO Hash owners can redeem their
/// NFTs to redeem an initial pro rata share of the deposited Wrapped ETH. Following the initial redemption period, a post 
/// redempion period can begin, wherein those users who redeemed their NFTs during the redemption period can redeem a pro rata
/// share of the remaining funds. The stages are as follows:
/// PreRedemption:  Redemptions have not begun; the multisig owner must deposit the DAO's Wrapped ETH via the setRedemptionStage()
///                 function to move the contract to the redemption stage.
/// Redemption:     Redemptions have begun, and all eligible DAO hash owners can redeem their NFTs using the redeem() function.
///                 After the MINREDEMPTIONTIME (180 days) has expired, the multisig owner can move the contract to the post 
///                 redemption stage via the setPostRedemptionStage() function.
/// PostRedemption: Post redemptions of the remaining WETH have begun. Users who successfully redeemed their DAO hashes during the 
///                 redemption stage can claim the remaining post redemption amount that is in proportion to the number of DAO
///                 hashes they initially redeemed.
/// @dev This contract must be deployed to Ethereum mainnet
contract Redemption is Ownable, ReentrancyGuard {
    /// CONSTANTS ///

    /// @notice Wrapped ETH
    ERC20 public constant WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    /// @notice Hashes NFT
    Hashes public constant HASHES = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);

    /// @notice Minimum number of Wrapped ETH that can deposited to enable the redemption stage
    uint256 public constant MINDEPOSITAMOUNT = 420;

    /// @notice Minimum number of Wrapped ETH that must remain to enable the post redemption stage
    uint256 public constant MINPOSTREDEMPTIONAMOUNT = 1;

    /// @notice Minimum time that the redemption stage must last before it is possible enable the post redemption stage
    uint256 public constant MINREDEMPTIONTIME = 180 days;
    
    /// @notice The initial number of eligible hashes used in the pro-rata redemption calculation
    /// @dev 1000 DAO hashes - (100 Dex labs hashes + 15 deactivated hashes + 67 bought back hashes)
    uint256 public constant INITIALNUMBEROFELIGIBLEHASHES = 818;
    
    /// VARIABLES ///

    /// @notice The current stage of the contract
    /// @dev Stages: PreRedemption -> Redemption -> PostRedemption
    Stages public stage;
    
    /// @notice The timestamp of when the redeption stage was set
    uint256 public redemptionSetTime;

    /// @notice Redemption stage redeem amount
    uint256 public redemptionPerHash;

    /// @notice PostRedemption stage redeem amount
    uint256 public postRedemptionPerHash;

    /// @notice Total number of DAO hashes redeemed during redemption stage
    uint256 public totalNumberRedeemed;
    
    /// @notice The number of DAO hashes any address has redeemed during the redemption stage
    mapping(address => uint256) public amountRedeemed;

    /// @notice Records whether a user's post redemption claim has been claimed
    mapping(address => bool) public postRedemptionClaimed;

    /// @notice DAO hash token Ids bought back by the DAO, and thus excluded from redemption
    mapping(uint256 => bool) public hashOwnedByDAO;

    /// CONSTRUCTOR ///

    constructor(address _redemptionMultiSig) {
        _transferOwnership(_redemptionMultiSig);
        _init();
        stage = Stages.PreRedemption;
    }

    /// EXTERNALS ///

    receive() external payable {
        revert();
    }

    /// @notice This function allows any eligible DAO hash owner to redeem their hashes for the initial pro rata redemption
    /// amount
    /// @param _tokenIds An array of eligible DAO hash token Ids
    /// @dev Owner of DAO hashes must approve contract to move them
    function redeem(uint256[] calldata _tokenIds) external nonReentrant {
        require(stage == Stages.Redemption, "Redemption: Must be in redemption stage");
        uint256 length = _tokenIds.length;
        require(length > 0, "Redemption: Must redeem more than zero Hashes");

        uint256 tokenId;
        for (uint256 i; i < length; i++) {
            tokenId = _tokenIds[i];
            require(
                isHashEligibleForRedemption(tokenId), 
                string(abi.encodePacked('Redemption: Hash with token Id #', Strings.toString(tokenId), ' is ineligible'))
            );
            HASHES.transferFrom(msg.sender, address(this), tokenId);
        }

        amountRedeemed[msg.sender] += length;
        totalNumberRedeemed += length;
        WETH.transfer(msg.sender, redemptionPerHash * length);
    }

    /// @notice This function allows users who redeemed their DAO hashes during the redemption stage to redeem the remaining
    /// post redemption amount
    /// NOTE Users who did not redeem eligible DAO hashes during the redemption stage will NOT be eligible to redeem during
    /// the post redemption stage
    function postRedeem() external nonReentrant {
        require(stage == Stages.PostRedemption, "Redemption: Must be in post-redemption stage");
        uint256 amountRedeemedByUser = amountRedeemed[msg.sender];
        require(amountRedeemedByUser > 0, "Redemption: User did not redeem any hashes during initial redemption period");
        require(!postRedemptionClaimed[msg.sender], "Redemption: User has already claimed post-redemption amount");

        postRedemptionClaimed[msg.sender] = true;
        WETH.transfer(msg.sender, postRedemptionPerHash * amountRedeemedByUser);
    }

    /// OWNER ONLY ///

    /// @notice This function allows the multisig owner to set the redemption stage by depositing the to-be-redeemed Wrapped ETH
    /// @param _amount The amount of WETH to be deposited for redemption
    /// NOTE The contract must be in the pre-redemption stage and the multisig owner must grant contract permission to move WETH
    function setRedemptionStage(uint256 _amount) external onlyOwner nonReentrant {
        require(stage == Stages.PreRedemption, "Redemption: Must be in pre-redemption stage");
        require(
            _amount >= MINDEPOSITAMOUNT * 10 ** WETH.decimals(),
            string(abi.encodePacked('Redemption: Must deposit at least ', Strings.toString(MINDEPOSITAMOUNT), ' WETH'))
        );

        WETH.transferFrom(msg.sender, address(this), _amount);
        redemptionPerHash = WETH.balanceOf(address(this)) / INITIALNUMBEROFELIGIBLEHASHES;
        redemptionSetTime = block.timestamp;
        stage = Stages.Redemption;
    }

    /// @notice This function allows the multisig owner to set the post redempion stage
    /// NOTE The contract must be in the redemption stage
    function setPostRedemptionStage() external onlyOwner nonReentrant {
        require(stage == Stages.Redemption, "Redemption: Must be in redemption stage");
        require(
            block.timestamp > redemptionSetTime + MINREDEMPTIONTIME,
            "Redemption: Minimum redemption time has not elapsed"
        );
        require(totalNumberRedeemed > 0, "Redemption: Nothing has been redeemed");
        uint256 wETHBalance = WETH.balanceOf(address(this));
        require(
            wETHBalance > MINPOSTREDEMPTIONAMOUNT * 10 ** WETH.decimals(),
            "Redemption: Contract does not contain minimum post redemption amount"
        );

        postRedemptionPerHash = wETHBalance / totalNumberRedeemed;
        stage = Stages.PostRedemption;
    }

    /// VIEWS ///

    /// @notice A view function that returns true if a given hashes token id is eligible for redemption, and false if not
    /// @param _tokenId The token Id of hash to be checked if eligible for redemption
    /// @return A boolean; true if eligible, false if not
    function isHashEligibleForRedemption(uint256 _tokenId) public view returns (bool) {
        if (_tokenId >= 1000) return false;             /// Non-DAO hash
        if (_tokenId < 100) return false;               /// Dex Labs hash
        if (HASHES.deactivated(_tokenId)) return false; /// Deactivated hash
        if (hashOwnedByDAO[_tokenId]) return false;     /// DAO-owned hash
        return true;
    }

    /// INTERNALS ///

    /// @dev Stores the token Ids the hashes bought back by the DAO, which are used to exclude them from redemptions
    function _init() internal {
        hashOwnedByDAO[236] = true;
        hashOwnedByDAO[440] = true;
        hashOwnedByDAO[220] = true;
        hashOwnedByDAO[818] = true;
        hashOwnedByDAO[461] = true;
        hashOwnedByDAO[786] = true;
        hashOwnedByDAO[280] = true;
        hashOwnedByDAO[268] = true;
        hashOwnedByDAO[185] = true;
        hashOwnedByDAO[314] = true;
        hashOwnedByDAO[938] = true;
        hashOwnedByDAO[637] = true;
        hashOwnedByDAO[393] = true;
        hashOwnedByDAO[835] = true;
        hashOwnedByDAO[837] = true;
        hashOwnedByDAO[291] = true;
        hashOwnedByDAO[659] = true;
        hashOwnedByDAO[729] = true;
        hashOwnedByDAO[352] = true;
        hashOwnedByDAO[287] = true;
        hashOwnedByDAO[982] = true;
        hashOwnedByDAO[965] = true;
        hashOwnedByDAO[305] = true;
        hashOwnedByDAO[958] = true;
        hashOwnedByDAO[585] = true;
        hashOwnedByDAO[520] = true;
        hashOwnedByDAO[845] = true;
        hashOwnedByDAO[844] = true;
        hashOwnedByDAO[750] = true;
        hashOwnedByDAO[506] = true;
        hashOwnedByDAO[614] = true;
        hashOwnedByDAO[634] = true;
        hashOwnedByDAO[807] = true;
        hashOwnedByDAO[759] = true;
        hashOwnedByDAO[960] = true;
        hashOwnedByDAO[873] = true;
        hashOwnedByDAO[678] = true;
        hashOwnedByDAO[836] = true;
        hashOwnedByDAO[737] = true;
        hashOwnedByDAO[828] = true;
        hashOwnedByDAO[866] = true;
        hashOwnedByDAO[718] = true;
        hashOwnedByDAO[599] = true;
        hashOwnedByDAO[533] = true;
        hashOwnedByDAO[687] = true;
        hashOwnedByDAO[920] = true;
        hashOwnedByDAO[590] = true;
        hashOwnedByDAO[595] = true;
        hashOwnedByDAO[584] = true;
        hashOwnedByDAO[618] = true;
        hashOwnedByDAO[918] = true;
        hashOwnedByDAO[512] = true;
        hashOwnedByDAO[531] = true;
        hashOwnedByDAO[610] = true;
        hashOwnedByDAO[290] = true;
        hashOwnedByDAO[574] = true;
        hashOwnedByDAO[754] = true;
        hashOwnedByDAO[791] = true;
        hashOwnedByDAO[860] = true;
        hashOwnedByDAO[955] = true;
        hashOwnedByDAO[701] = true;
        hashOwnedByDAO[740] = true;
        hashOwnedByDAO[577] = true;
        hashOwnedByDAO[250] = true;
        hashOwnedByDAO[195] = true;
        hashOwnedByDAO[182] = true;
        hashOwnedByDAO[926] = true;
    }
}

/// @dev Stages of the redemption contract
enum Stages {
    PreRedemption,
    Redemption,
    PostRedemption
}