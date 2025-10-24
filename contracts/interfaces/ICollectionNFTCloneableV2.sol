// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import {ICollectionNFTEligibilityPredicate} from "../interfaces/ICollectionNFTEligibilityPredicate.sol";
import {ICollectionNFTMintFeePredicate} from "../interfaces/ICollectionNFTMintFeePredicate.sol";
import {ICollectionNFTTokenURIPredicate} from "../interfaces/ICollectionNFTTokenURIPredicate.sol";

interface ICollectionNFTCloneableV2 {
    function mint(uint256 _hashesTokenId) external payable;

    function burn(uint256 _tokenId) external;

    function completeSignatureBlock() external;

    function setRoyaltyBps(uint16 _royaltyBps) external;

    function transferCreator(address _creatorAddress) external;

    function setSignatureBlockAddress(address _signatureBlockAddress) external;

    function withdraw() external;

    function nonce() external view returns (uint256);

    function cap() external view returns (uint256);

    function mintEligibilityPredicateContract() external view returns (ICollectionNFTEligibilityPredicate);

    function mintFeePredicateContract() external view returns (ICollectionNFTMintFeePredicate);

    function TokenURIPredicateContract() external view returns (ICollectionNFTTokenURIPredicate);

    function tokenCollectionIdToHashesIdMapping(uint256 _hashesTokenId)
        external
        view
        returns (bool exists, uint256 tokenId, bytes32 hashesHash);
}
