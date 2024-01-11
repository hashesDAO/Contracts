// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

/// NOTE This is a template test contract that can be used to fork Ethereum Mainnet and test integrations 
/// with the already deployed Hashes DAO smart contracts.
import "forge-std/Test.sol";
import "forge-std/console.sol";

/// DAO
import {Hashes} from "../contracts/Hashes.sol";
import {HashesDAO} from "../contracts/HashesDAO.sol";

/// Factory
import {CollectionFactory} from "../contracts/hashes_collections/CollectionFactory.sol";
/// Implementations
import {CollectionNFTCloneableV1} from "../contracts/hashes_collections/CollectionNFTCloneableV1.sol";
import {CollectionNFTCloneableV2} from "../contracts/hashes_collections/CollectionNFTCloneableV2.sol";
/// Predicates
import {CollectionPaymentSplitterCloneable} from "../contracts/hashes_collections/CollectionPaymentSplitterCloneable.sol";
import {MultiStageAllowlistCloneable} from "../contracts/hashes_collections/MultiStageAllowlistCloneable.sol";
import {PaymentSplitterCloneable} from "../contracts/hashes_collections/PaymentSplitterCloneable.sol";

contract HashesFork is Test {
    Hashes public hashes;
    HashesDAO public hashesDAO;

    CollectionFactory public collectionFactory;
    CollectionNFTCloneableV1 public collectionNFTCloneableV1;
    CollectionNFTCloneableV2 public collectionNFTCloneableV2;
    CollectionPaymentSplitterCloneable public collectionPaymentSplitterCloneable;
    MultiStageAllowlistCloneable public multiStageAllowlistCloneable;
    PaymentSplitterCloneable public paymentSplitterCloneable;

    function setUp() public {
        string memory rpcURL = vm.envString("RPC_URL");
        uint256 mainnetFork = vm.createFork(rpcURL);
        vm.selectFork(mainnetFork);

        hashes = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);
        hashesDAO = HashesDAO(payable(0xbD3Af18e0b7ebB30d49B253Ab00788b92604552C));

        collectionFactory = CollectionFactory(0x86cF8621b3ee3EB77D7EFFE9Dc677D1CD39E9Ce5);
        collectionNFTCloneableV1 = CollectionNFTCloneableV1(payable(0xE023e03Dca09E3e467251d29057cfd2CcDd797A9));
        collectionNFTCloneableV2 = CollectionNFTCloneableV2(payable(0x9b43aE24542C548341C3bb24aDe8D22f59C92ae6));
        collectionPaymentSplitterCloneable = CollectionPaymentSplitterCloneable(payable(0x719d437A3525012D6fdafc9db3159CeC57adba37));
        multiStageAllowlistCloneable = MultiStageAllowlistCloneable(0xE53c5FcE669d16F61204C1ae0DBD699085d07CC9);
        paymentSplitterCloneable = PaymentSplitterCloneable(payable(0x719d437A3525012D6fdafc9db3159CeC57adba37));
    }

    function testInit() public {
        assertGt(hashes.nonce(), 1e3);
    }
}