// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

/// NOTE This is a template/example test contract that can be used to fork Ethereum Mainnet and test integrations
/// with the already deployed Hashes DAO smart contracts.
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

/// Utils
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// DAO
import {Hashes} from "contracts/Hashes.sol";
import {HashesDAO} from "contracts/HashesDAO.sol";

/// Factory
import {CollectionFactory} from "contracts/hashes_collections/CollectionFactory.sol";
/// Implementations
import {CollectionNFTCloneableV1} from "contracts/hashes_collections/CollectionNFTCloneableV1.sol";
import {CollectionNFTCloneableV2} from "contracts/hashes_collections/CollectionNFTCloneableV2.sol";
/// Predicates
import {CollectionPaymentSplitterCloneable} from "contracts/hashes_collections/CollectionPaymentSplitterCloneable.sol";
import {MultiStageAllowlistCloneable} from "contracts/hashes_collections/MultistageAllowlistCloneable.sol";
import {PaymentSplitterCloneable} from "contracts/hashes_collections/PaymentSplitterCloneable.sol";

contract HashesFork is Test {
    ERC20 public WETH;

    Hashes public hashes;
    HashesDAO public hashesDAO;

    CollectionFactory public collectionFactory;
    CollectionNFTCloneableV1 public collectionNFTCloneableV1;
    CollectionNFTCloneableV2 public collectionNFTCloneableV2;
    CollectionPaymentSplitterCloneable public collectionPaymentSplitterCloneable;
    MultiStageAllowlistCloneable public multiStageAllowlistCloneable;
    PaymentSplitterCloneable public paymentSplitterCloneable;

    address public hashesDeployer; /// 100 DAO Hashes

    function setUp() public {
        vm.selectFork(vm.createFork(vm.envString("RPC_URL")));

        WETH = ERC20(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

        hashes = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);
        hashesDAO = HashesDAO(payable(0xbD3Af18e0b7ebB30d49B253Ab00788b92604552C));

        collectionFactory = CollectionFactory(0x86cF8621b3ee3EB77D7EFFE9Dc677D1CD39E9Ce5);
        collectionNFTCloneableV1 = CollectionNFTCloneableV1(payable(0xE023e03Dca09E3e467251d29057cfd2CcDd797A9));
        collectionNFTCloneableV2 = CollectionNFTCloneableV2(payable(0x9b43aE24542C548341C3bb24aDe8D22f59C92ae6));
        collectionPaymentSplitterCloneable =
            CollectionPaymentSplitterCloneable(payable(0x719d437A3525012D6fdafc9db3159CeC57adba37));
        multiStageAllowlistCloneable = MultiStageAllowlistCloneable(0xE53c5FcE669d16F61204C1ae0DBD699085d07CC9);
        paymentSplitterCloneable = PaymentSplitterCloneable(payable(0x719d437A3525012D6fdafc9db3159CeC57adba37));

        hashesDeployer = 0xEE1DDffcb15C00911d0F78c1A1C75C79b77C5d66;
    }

    function testInit() public {
        assertGt(hashes.nonce(), 1e3);
    }

    function testWithdrawETHFromDAO() public {
        vm.startPrank(hashesDeployer);

        uint256 ethAmount = 10e18;
        uint256 hashesDeployerBalanceBefore = address(hashesDeployer).balance;

        /// Create Proposal
        address[] memory targets = new address[](1);
        targets[0] = hashesDeployer;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ethAmount;

        string[] memory signatures = new string[](1);
        signatures[0] = "call()";

        bytes[] memory callData = new bytes[](1);
        callData[0] = "";

        hashesDAO.propose(targets, amounts, signatures, callData, "Withdraw ETH Test");

        vm.roll(block.number + 2);

        /// Vote
        uint128 proposalId = hashesDAO.getProposalCount();

        hashesDAO.castVote(proposalId, true, false, "0x");

        vm.roll(block.number + 17820);

        /// Queue
        hashesDAO.queue(proposalId);

        vm.warp(block.timestamp + 3 days);

        /// Execute
        hashesDAO.execute(proposalId);

        uint256 hashesDeployerBalanceAfter = address(hashesDeployer).balance;

        /// Checks
        assertEq(hashesDeployerBalanceAfter, hashesDeployerBalanceBefore + ethAmount);

        vm.stopPrank();
    }

    function testWithdrawRETHFromDAO() public {
        vm.startPrank(hashesDeployer);

        /// Send the DAO some RocketPool ETH

        ERC20 RETH = ERC20(payable(0xae78736Cd615f374D3085123A210448E74Fc6393));
        uint256 rethAmount = 10e18;

        deal(address(RETH), address(hashesDAO), rethAmount);

        uint256 hashesDeployerBalanceBefore = RETH.balanceOf(hashesDeployer);

        /// Create Proposal
        address[] memory targets = new address[](1);
        targets[0] = address(RETH);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "transfer(address,uint256)";

        bytes[] memory callData = new bytes[](1);
        callData[0] = abi.encodePacked([hashesDeployer], [rethAmount]);

        hashesDAO.propose(targets, amounts, signatures, callData, "Withdraw WETH Test");

        vm.roll(block.number + 2);

        /// Vote
        uint128 proposalId = hashesDAO.getProposalCount();

        hashesDAO.castVote(proposalId, true, false, "0x");

        vm.roll(block.number + 17820);

        /// Queue
        hashesDAO.queue(proposalId);

        vm.warp(block.timestamp + 3 days);

        /// Execute
        hashesDAO.execute(proposalId);

        uint256 hashesDeployerBalanceAfter = RETH.balanceOf(hashesDeployer);

        /// Checks
        assertEq(hashesDeployerBalanceAfter, hashesDeployerBalanceBefore + rethAmount);

        vm.stopPrank();
    }
}
