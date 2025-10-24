// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {ICollectionNFTEligibilityPredicate} from "../interfaces/ICollectionNFTEligibilityPredicate.sol";
import {ICollectionNFTMintFeePredicate} from "../interfaces/ICollectionNFTMintFeePredicate.sol";

interface ICollectionNFTCloneable {
    event Minted(address indexed minter, uint256 indexed tokenId, uint256 indexed hashesTokenId);

    function withdraw() external;

    function mint(uint256 _hashesTokenId) external payable;

    function burn(uint256 _tokenId) external;

    function completeSignatureBlock() external;

    function setRoyaltyBps(uint16 _royaltyBps) external;

    function transferCreator(address _creatorAddress) external;

    function setSignatureBlockAddress(address _signatureBlockAddress) external;

    function nonce() external view returns (uint256);

    function cap() external view returns (uint256);

    function mintEligibilityPredicateContract() external view returns (ICollectionNFTEligibilityPredicate);

    function mintFeePredicateContract() external view returns (ICollectionNFTMintFeePredicate);

    function hashesIdToCollectionTokenIdMapping(uint256 _hashesTokenId)
        external
        view
        returns (bool exists, uint256 tokenId);

    function balanceOf(address owner) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}
