// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Hashes} from "contracts/Hashes.sol";
import {HashesDAO} from "contracts/HashesDAO.sol";
import {Stages, Redemption} from "contracts/redemption/Redemption.sol";

/// @dev Test suite for the Hashes DAO redemption contract
contract RedemptionTests is Test {
    ERC20 public wETH;
    Hashes public hashes;
    HashesDAO public hashesDAO;
    Redemption public redemption;
    address public redemptionMultisig;
    address public hashHolder0;
    address public hashHolder1;
    address public dexLabs;
    address public deactivatedHolder;
    address public daoWallet;

    function setUp() public {
        string memory rpcURL = vm.envString("RPC_URL");
        uint256 mainnetFork = vm.createFork(rpcURL);
        vm.selectFork(mainnetFork);

        redemptionMultisig = address(420);
        vm.deal(redemptionMultisig, 1_000_000 ether);

        wETH = ERC20(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        hashes = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);
        hashesDAO = HashesDAO(payable(0xbD3Af18e0b7ebB30d49B253Ab00788b92604552C));
        redemption = new Redemption(redemptionMultisig);
        hashHolder0 = address(0x391b4A553551606Bbd1CDee08A0fA31f8548F3DC);
        hashHolder1 = address(0xd958bBEfB7513b083A74962e49f759745f36B008);
        dexLabs = address(0xEE1DDffcb15C00911d0F78c1A1C75C79b77C5d66);
        deactivatedHolder = address(0xAFcd6E3D6B8E87722eD8d5a598e811672A462a9d);
        daoWallet = address(0x391b4A553551606Bbd1CDee08A0fA31f8548F3DC);

        /*
        /// Award the redemption multisig a DAO hash to expedite stage jumps
        vm.startPrank(hashHolder1);
        hashes.transferFrom(hashHolder1, address(redemptionMultisig), 301);
        hashes.transferFrom(hashHolder1, hashHolder0, 870);
        vm.stopPrank();

        /// Award DAOHashHolder0 a DexLabs, deactivated, and DAOWallet hash
        vm.startPrank(dexLabs);
        hashes.transferFrom(dexLabs, hashHolder0, 0);
        vm.stopPrank();

        vm.startPrank(deactivatedHolder);
        hashes.transferFrom(deactivatedHolder, hashHolder0, 424);
        vm.stopPrank();

        vm.startPrank(daoWallet);
        hashes.transferFrom(daoWallet, hashHolder0, 920);
        vm.stopPrank();
        */
    }
    /*

    /// @dev Tests constants and owner
    function testInitialisation() public {
        assertEq(address(redemption.WETH()), address(wETH));
        assertEq(address(redemption.HASHES()), address(hashes));
        assertEq(redemption.MINDEPOSITAMOUNT(), 420);
        assertEq(redemption.MINPOSTREDEMPTIONAMOUNT(), 1);
        assertEq(redemption.MINREDEMPTIONTIME(), 180 days);
        assertEq(redemption.INITIALNUMBEROFELIGIBLEHASHES(), 818);
        assertEq(redemption.owner(), redemptionMultisig);
    }

    /// @dev Tests the receive function to revert
    function testReceiveRevert() public {
        vm.expectRevert();
        (bool s,) = address(redemption).call{value: 1 ether}("");
        s;
    }

    /// REDEMPTION ///

    /// @dev Tests Redeem function revert conditions
    function testRedeemRevertConditions(uint256 _amount) public {
        /// Non-Redemption stage - PreRedemption
        vm.startPrank(hashHolder0);
        uint256[] memory set = new uint256[](2);
        set[0] = 241;
        set[1] = 883;

        vm.expectRevert("Redemption: Must be in redemption stage");
        redemption.redeem(set);
        vm.stopPrank();

        vm.startPrank(redemptionMultisig);
        _setRedemptionStage(_amount);
        vm.stopPrank();

        /// Redeemer has not granted redemption contract permissions
        vm.startPrank(hashHolder0);
        vm.expectRevert("ERC721: transfer caller is not owner nor approved");
        redemption.redeem(set);

        hashes.setApprovalForAll(address(redemption), true);

        /// Redeem zero
        uint256[] memory zeroSet = new uint256[](0);
        vm.expectRevert("Redemption: Must redeem more than zero Hashes");
        redemption.redeem(zeroSet);

        /// Redeem ineligible - Non-DAO hash
        set[0] = 3147;
        vm.expectRevert("Redemption: Hash with token Id #3147 is ineligible");
        redemption.redeem(set);

        /// Redeem ineligible - Dex Labs hash
        set[0] = 241;
        set[1] = 0;
        vm.expectRevert("Redemption: Hash with token Id #0 is ineligible");
        redemption.redeem(set);

        /// Redeem ineligible - Deactivated hash
        set[1] = 424;
        vm.expectRevert("Redemption: Hash with token Id #424 is ineligible");
        redemption.redeem(set);

        /// Redeem ineligible - DAO-owned hash
        set[1] = 920;
        vm.expectRevert("Redemption: Hash with token Id #920 is ineligible");
        redemption.redeem(set);

        /// Redeem an already redeemed Hash
        set[1] = 883;
        redemption.redeem(set);
        vm.expectRevert("ERC721: transfer of token that is not own");
        redemption.redeem(set);

        vm.stopPrank();

        /// Non-Redemption stage - PostRedemption
        vm.startPrank(redemptionMultisig);
        _setPostRedemptionStage();
        vm.stopPrank();

        vm.startPrank(hashHolder0);
        set[0] = 870;
        set[1] = 706;

        vm.expectRevert("Redemption: Must be in redemption stage");
        redemption.redeem(set);
        vm.stopPrank();
    }

    /// @dev Tests the Redeem function success conditions
    function testRedeemSuccess(uint256 _amount) public {
        /// Set redemption stage
        vm.startPrank(redemptionMultisig);
        _setRedemptionStage(_amount);
        vm.stopPrank();

        /// Two users redeem their hashses
        uint256 redemptionBalaceBefore = wETH.balanceOf(address(redemption));
        uint256 hashHolder0BalanceBefore = wETH.balanceOf(hashHolder0);
        uint256 hashHolder1BalanceBefore = wETH.balanceOf(hashHolder1);

        vm.startPrank(hashHolder0);
        uint256[] memory set0 = new uint256[](2);
        set0[0] = 241;
        set0[1] = 883;

        hashes.setApprovalForAll(address(redemption), true);
        redemption.redeem(set0);

        vm.stopPrank();
        vm.startPrank(hashHolder1);

        uint256[] memory set1 = new uint256[](8);
        set1[0] = 964;
        set1[1] = 405;
        set1[2] = 672;
        set1[3] = 382;
        set1[4] = 580;
        set1[5] = 497;
        set1[6] = 257;
        set1[7] = 448;

        hashes.setApprovalForAll(address(redemption), true);
        redemption.redeem(set1);

        /// Test correct transfer of assets
        uint256 redemptionPerHash = redemption.redemptionPerHash();
        assertGt(redemptionPerHash, 0);

        assertEq(redemption.totalNumberRedeemed(), hashes.balanceOf(address(redemption)));
        assertEq(redemption.totalNumberRedeemed(), redemption.amountRedeemed(hashHolder0) + redemption.amountRedeemed(hashHolder1));
        assertEq(redemption.totalNumberRedeemed(), 10);
        assertEq(redemptionBalaceBefore, wETH.balanceOf(address(redemption)) + (redemptionPerHash * 10));
        assertEq(hashHolder0BalanceBefore, wETH.balanceOf(hashHolder0) - (redemptionPerHash * 2));
        assertEq(hashHolder1BalanceBefore, wETH.balanceOf(hashHolder1) - (redemptionPerHash * 8));

        vm.stopPrank();
    }

    /// POSTREDEMPTION ///

    /// @dev Tests the PostRedeem function revert conditions
    function testPostRedeemRevertConditions(uint256 _amount) public {
        /// Non-Redemption stage - PreRedemption
        vm.expectRevert("Redemption: Must be in post-redemption stage");
        redemption.postRedeem();

        /// Non-Redemption stage - Redemption
        vm.startPrank(redemptionMultisig);
        _setRedemptionStage(_amount);
        vm.expectRevert("Redemption: Must be in post-redemption stage");
        redemption.postRedeem();
        _setPostRedemptionStage();
        vm.stopPrank();

        /// User did not redeem during redemption period
        vm.startPrank(hashHolder0);
        vm.expectRevert("Redemption: User did not redeem any hashes during initial redemption period");
        redemption.postRedeem();
        vm.stopPrank();

        /// User already claimed postRedemption amount
        vm.startPrank(redemptionMultisig);
        redemption.postRedeem();
        vm.expectRevert("Redemption: User has already claimed post-redemption amount");
        redemption.postRedeem();
        vm.stopPrank();
    }

    /// @dev Test PostRedeem function success conditions
    function testPostRedeemSuccess(uint256 _amount) public {
        /// Set redemption stage
        vm.startPrank(redemptionMultisig);
        _setRedemptionStage(_amount);
        vm.stopPrank();

        /// Two users redeem their hashes
        uint256 redemptionBalaceBefore = wETH.balanceOf(address(redemption));
        uint256 hashHolder0BalanceBefore = wETH.balanceOf(hashHolder0);
        uint256 hashHolder1BalanceBefore = wETH.balanceOf(hashHolder1);

        vm.startPrank(hashHolder0);
        uint256[] memory set0 = new uint256[](2);
        set0[0] = 241;
        set0[1] = 883;

        hashes.setApprovalForAll(address(redemption), true);
        redemption.redeem(set0);

        vm.stopPrank();
        vm.startPrank(hashHolder1);

        uint256[] memory set1 = new uint256[](8);
        set1[0] = 964;
        set1[1] = 405;
        set1[2] = 672;
        set1[3] = 382;
        set1[4] = 580;
        set1[5] = 497;
        set1[6] = 257;
        set1[7] = 448;

        hashes.setApprovalForAll(address(redemption), true);
        redemption.redeem(set1);
        vm.stopPrank();

        vm.startPrank(redemptionMultisig);
        _setPostRedemptionStage();
        vm.stopPrank();

        /// Two users claim their post redemption
        vm.startPrank(hashHolder0);
        redemption.postRedeem();
        vm.stopPrank();

        vm.startPrank(hashHolder1);
        redemption.postRedeem();
        vm.stopPrank();

        /// Checks the correct transfer of funds and updated variables
        /// @dev 11 redemptions including 1 from redemption multisig
        uint256 redemptionPerHash = redemption.redemptionPerHash();
        uint256 postRedemptionPerHash = redemption.postRedemptionPerHash();
        assertGt(redemptionPerHash, 0);
        assertGt(postRedemptionPerHash, 0);

        assertEq(
            redemptionBalaceBefore,
            wETH.balanceOf(address(redemption)) + (redemptionPerHash * 11) + (postRedemptionPerHash * 10)
        );
        assertEq(
            hashHolder0BalanceBefore,
            wETH.balanceOf(hashHolder0) - ((redemptionPerHash * 2) + (postRedemptionPerHash * 2))
        );
        assertEq(
            hashHolder1BalanceBefore,
            wETH.balanceOf(hashHolder1) - ((redemptionPerHash * 8) + (postRedemptionPerHash * 8))
        );
        assertEq(redemption.postRedemptionClaimed(hashHolder0), true);
        assertEq(redemption.postRedemptionClaimed(hashHolder1), true);
    }

    /// OWNER ///

    /// @dev Tests non-Owner fail conditions on onlyOwner functions
    function testnonOwnerFailConditions() public prank(hashHolder0) {
        vm.expectRevert("Ownable: caller is not the owner");
        redemption.setRedemptionStage(0);
        vm.expectRevert("Ownable: caller is not the owner");
        redemption.setPostRedemptionStage();
    }

    /// @dev Tests SetRedemption function
    function testSetRedemptionStage(uint256 _amount) public prank(redemptionMultisig) {
        uint256 minDeposit = redemption.MINDEPOSITAMOUNT() * 10 ** uint256(wETH.decimals());
        _amount = bound(_amount, minDeposit, 1000 ether);

        /// Award multisig some WETH
        (bool _success, ) = address(wETH).call{value: _amount}("");
        require(_success);

        /// Fail if deposit too low
        vm.expectRevert("Redemption: Must deposit at least 420 WETH");
        redemption.setRedemptionStage(minDeposit - 1);

        /// Fail if WETH approval not granted
        vm.expectRevert();
        redemption.setRedemptionStage(_amount);

        /// Success
        wETH.approve(address(redemption), _amount);
        redemption.setRedemptionStage(_amount);

        assertEq(wETH.balanceOf(address(redemption)), _amount);
        assertEq(wETH.balanceOf(address(redemption)) / redemption.INITIALNUMBEROFELIGIBLEHASHES(), redemption.redemptionPerHash());
        assertEq(block.timestamp, redemption.redemptionSetTime());

        /// Fail to call if not in PreRedemption Stage
        /// Redemption
        vm.expectRevert("Redemption: Must be in pre-redemption stage");
        redemption.setRedemptionStage(_amount);

        /// PostRedemption
        _setPostRedemptionStage();
        vm.expectRevert("Redemption: Must be in pre-redemption stage");
        redemption.setRedemptionStage(_amount);
    }

    /// @dev Tests SetPostRedemption function
    function testSetPostRedemptionStage(uint256 _amount) public prank(redemptionMultisig) {
        /// Fail if not in redemption stage: pre-redemption
        vm.expectRevert("Redemption: Must be in redemption stage");
        redemption.setPostRedemptionStage();

        /// Set redemption stage
        _setRedemptionStage(_amount);

        /// Not enough time has elapsed
        vm.expectRevert("Redemption: Minimum redemption time has not elapsed");
        redemption.setPostRedemptionStage();

        /// Nothing has been redeemed
        vm.warp(redemption.redemptionSetTime() + redemption.MINREDEMPTIONTIME() + 1);

        vm.expectRevert("Redemption: Nothing has been redeemed");
        redemption.setPostRedemptionStage();

        uint256[] memory set = new uint256[](1);
        set[0] = 301;

        hashes.approve(address(redemption), 301);
        redemption.redeem(set);

        uint256 redemptionBalanceBeforeDeal = wETH.balanceOf(address(redemption));

        /// Not enough WETH left for post redemption
        deal(address(wETH), address(redemption), 1 ether - 1);

        vm.expectRevert("Redemption: Contract does not contain minimum post redemption amount");
        redemption.setPostRedemptionStage();

        deal(address(wETH), address(redemption), redemptionBalanceBeforeDeal);

        /// Success
        redemption.setPostRedemptionStage();

        assertEq(redemption.postRedemptionPerHash(), redemptionBalanceBeforeDeal / redemption.totalNumberRedeemed());

        /// Fail if not in redemption stage: post-redemption
        vm.expectRevert("Redemption: Must be in redemption stage");
        redemption.setPostRedemptionStage();
    }

    /// UTILS ///

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    /// @dev Must be called by Redemption Multisig
    /// PreRedemption -> Redemption
    function _setRedemptionStage(uint256 _amount) internal {
        uint256 minDeposit = redemption.MINDEPOSITAMOUNT() * 10 ** uint256(wETH.decimals());
        _amount = bound(_amount, minDeposit, 1000 ether);

        (bool _success, ) = address(wETH).call{value: _amount}("");
        require(_success);

        wETH.approve(address(redemption), _amount);
        redemption.setRedemptionStage(_amount);
    }

    /// @dev Must be called by Redemption Multisig
    /// Redemption -> PostRedemption
    function _setPostRedemptionStage() internal {
        uint256[] memory set = new uint256[](1);
        set[0] = 301;

        hashes.approve(address(redemption), 301);
        redemption.redeem(set);

        vm.warp(redemption.redemptionSetTime() + redemption.MINREDEMPTIONTIME() + 1);
        redemption.setPostRedemptionStage();
    }
    */
}
