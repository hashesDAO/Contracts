// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Hashes} from "contracts/Hashes.sol";
import {Redemption, IRedemption} from "contracts/redemption/Redemption.sol";
import {DeployRedemption} from "script/DeployRedemption.s.sol";

/// @dev Fork test suite for the Hashes DAO redemption contract
contract RedemptionForkTest is Test, DeployRedemption {
    event Deposit(address _user, uint256 _amount);
    event Redeemed(address _user, uint256 _amount);
    event StageSet(IRedemption.Stages _stage);

    ERC20 public wETH;
    Hashes public hashes;

    address public hashHolder0;
    address public hashHolder1;
    address public dexLabs;
    address public deactivatedHolder;
    address public daoWallet;

    uint256 public depositAmount;

    modifier prank(address _caller) {
        vm.startPrank(_caller);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();
        vm.selectFork(vm.createFork(vm.envString("RPC_URL")));

        wETH = ERC20(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        hashes = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);
        hashHolder0 = address(0x7896490EC41282CA6f80870448e9A0eEB022746E);
        dexLabs = address(0xEE1DDffcb15C00911d0F78c1A1C75C79b77C5d66);

        // Deal redemption multisig ETH and a valid DAO hash
        depositAmount = 325 ether;
        vm.deal(redemptionMultisig, 10 * depositAmount);
        vm.prank(hashHolder0);
        hashes.transferFrom(hashHolder0, redemptionMultisig, 227);

        // Deploy contract
        vm.expectEmit(true, true, true, true);
        emit StageSet(IRedemption.Stages.PreRedemption);
        run();
    }

    /// PreRedemption ///

    function testInit() public {
        assertEq(address(redemption.HASHES()), address(hashes));
        assertEq(redemption.MIN_REDEMPTION_TIME(), 180 days);
        assertEq(redemption.INITIAL_ELIGIBLE_HASHES_TOTAL(), 520);
        assertEq(redemption.redemptionSetTime(), 0);
        assertEq(redemption.redemptionPerHash(), 0);
        assertEq(redemption.totalNumberRedeemed(), 0);
        assert(redemption.stage() == IRedemption.Stages.PreRedemption);
    }

    function testRedeemFailure() public {
        vm.expectRevert(IRedemption.WrongStage.selector);
        redemption.redeem();
    }

    function testDeposit() public prank(redemptionMultisig) {
        uint256 balanceBefore = address(redemption).balance;
        assertEq(balanceBefore, 0);

        // Deposit with deposit()
        vm.expectEmit(true, true, true, true);
        emit Deposit(redemptionMultisig, depositAmount);
        redemption.deposit{value: depositAmount}();

        uint256 balanceAfterA = address(redemption).balance;
        assertEq(balanceAfterA, balanceBefore + depositAmount);

        // Deposit with call
        vm.expectEmit(true, true, true, true);
        emit Deposit(redemptionMultisig, depositAmount);
        (bool s,) = address(redemption).call{value: depositAmount}("");
        require(s);

        uint256 balanceAfterB = address(redemption).balance;
        assertEq(balanceAfterB, balanceBefore + (2 * depositAmount));
    }

    function testSetRedemptionStage() public prank(redemptionMultisig) {
        // Fund the contract
        redemption.deposit{value: depositAmount}();

        // Set stage to redemption
        vm.expectEmit(true, true, true, true);
        emit StageSet(IRedemption.Stages.Redemption);
        redemption.setRedemptionStage();

        assertEq(redemption.redemptionSetTime(), block.timestamp);
        assertEq(redemption.redemptionPerHash(), depositAmount / redemption.INITIAL_ELIGIBLE_HASHES_TOTAL());
        assert(redemption.stage() == IRedemption.Stages.Redemption);
    }

    function testSetPostRedemptionStageFailureWrongStage() public prank(redemptionMultisig) {
        vm.expectRevert(IRedemption.WrongStage.selector);
        redemption.setPostRedemptionStage();
    }

    /// Redemption ///

    function testDexLabsRedeemInitial() public {
        // Set up
        vm.startPrank(redemptionMultisig);
        redemption.deposit{value: depositAmount}();
        redemption.setRedemptionStage();
        vm.stopPrank();

        uint256 redemptionBalanceBefore = address(redemption).balance;
        uint256 dexLabsBalanceBefore = dexLabs.balance;
        assertEq(redemptionBalanceBefore, depositAmount);

        // Dex Labs redeems their 99 DAO hashes
        vm.expectEmit(true, true, true, true);
        emit Redeemed(dexLabs, 99 * redemption.redemptionPerHash());
        vm.prank(dexLabs);
        redemption.redeem();

        uint256 redemptionBalanceAfterA = address(redemption).balance;
        uint256 dexLabsBalanceAfterA = dexLabs.balance;
        assertEq(redemptionBalanceAfterA, redemptionBalanceBefore - (99 * redemption.redemptionPerHash()));
        assertEq(dexLabsBalanceAfterA, dexLabsBalanceBefore + (99 * redemption.redemptionPerHash()));
        assertEq(redemption.totalNumberRedeemed(), 99);

        // Dex Labs attempts to redeem again and gets nothing more
        vm.expectEmit(true, true, true, true);
        emit Redeemed(dexLabs, 0);
        vm.prank(dexLabs);
        redemption.redeem();

        uint256 redemptionBalanceAfterB = address(redemption).balance;
        uint256 dexLabsBalanceAfterB = dexLabs.balance;
        assertEq(redemptionBalanceAfterB, redemptionBalanceAfterA);
        assertEq(dexLabsBalanceAfterB, dexLabsBalanceAfterA);
        assertEq(redemption.totalNumberRedeemed(), 99);
    }

    function testDepositAfterRedemptionStageSet() public prank(redemptionMultisig) {
        // Set up
        redemption.deposit{value: depositAmount}();
        redemption.setRedemptionStage();
        assertEq(redemption.redemptionPerHash(), depositAmount / redemption.INITIAL_ELIGIBLE_HASHES_TOTAL());

        // Additional deposit does not change initial redemption rate
        redemption.deposit{value: depositAmount}();
        assertEq(redemption.redemptionPerHash(), depositAmount / redemption.INITIAL_ELIGIBLE_HASHES_TOTAL());
    }

    function testSetRedemptionStageWrongStage() public prank(redemptionMultisig) {
        redemption.setRedemptionStage();
        vm.expectRevert(IRedemption.WrongStage.selector);
        redemption.setRedemptionStage();
    }

    function testSetPostRedemptionStageFailureNoRedemptions() public prank(redemptionMultisig) {
        redemption.setRedemptionStage();
        vm.expectRevert();
        redemption.setPostRedemptionStage();
    }

    function testSetPostRedemptionStage() public prank(redemptionMultisig) {
        // Set up
        redemption.deposit{value: depositAmount}();
        redemption.setRedemptionStage();
        redemption.redeem();
        assertEq(redemption.redemptionPerHash(), depositAmount / redemption.INITIAL_ELIGIBLE_HASHES_TOTAL());
        vm.warp(block.timestamp + redemption.MIN_REDEMPTION_TIME() + 1);

        // Set Post Redemption stage
        vm.expectEmit(true, true, true, true);
        emit StageSet(IRedemption.Stages.PostRedemption);
        redemption.setPostRedemptionStage();
        assertEq(
            redemption.redemptionPerHash(),
            (depositAmount - (depositAmount / redemption.INITIAL_ELIGIBLE_HASHES_TOTAL()))
                / redemption.totalNumberRedeemed()
        );
    }

    /// PostRedemption ///

    function testDexLabsRedeemFinal() public {
        // Set up
        vm.startPrank(redemptionMultisig);
        redemption.deposit{value: depositAmount}();
        redemption.setRedemptionStage();
        vm.warp(block.timestamp + redemption.MIN_REDEMPTION_TIME() + 1);
        vm.stopPrank();

        // Dex Labs redeems their 99 DAO hashes initially
        vm.prank(dexLabs);
        redemption.redeem();

        // Set to Post Redemption stage
        vm.prank(redemptionMultisig);
        redemption.setPostRedemptionStage();
        uint256 redemptionBalanceBefore = address(redemption).balance;
        uint256 dexLabsBalanceBefore = dexLabs.balance;

        // Dex Labs redeems again
        vm.expectEmit(true, true, true, true);
        emit Redeemed(dexLabs, 99 * redemption.redemptionPerHash());
        vm.prank(dexLabs);
        redemption.redeem();
        uint256 redemptionBalanceAfterA = address(redemption).balance;
        uint256 dexLabsBalanceAfterA = dexLabs.balance;
        assertEq(redemptionBalanceAfterA, redemptionBalanceBefore - (99 * redemption.redemptionPerHash()));
        assertEq(dexLabsBalanceAfterA, dexLabsBalanceBefore + (99 * redemption.redemptionPerHash()));

        // Dex Labs attempts to redeem again (again) and gets nothing more
        vm.expectEmit(true, true, true, true);
        emit Redeemed(dexLabs, 0);
        vm.prank(dexLabs);
        redemption.redeem();

        uint256 redemptionBalanceAfterB = address(redemption).balance;
        uint256 dexLabsBalanceAfterB = dexLabs.balance;
        assertEq(redemptionBalanceAfterB, redemptionBalanceAfterA);
        assertEq(dexLabsBalanceAfterB, dexLabsBalanceAfterA);
    }

    function testDepositFailure() public prank(redemptionMultisig) {
        // Set Redemption stage
        redemption.setRedemptionStage();
        redemption.redeem();

        // Set Post Redemption stage
        vm.warp(block.timestamp + redemption.MIN_REDEMPTION_TIME() + 1);
        redemption.setPostRedemptionStage();

        // Revert with deposit()
        vm.expectRevert(IRedemption.WrongStage.selector);
        redemption.deposit{value: depositAmount}();

        // Revert with call
        vm.expectRevert(IRedemption.WrongStage.selector);
        (bool s,) = address(redemption).call{value: depositAmount}("");
        require(s);
    }

    /// Misc ///

    function testRecoverERC20() public prank(redemptionMultisig) {
        // Set up
        deal(address(wETH), address(redemption), depositAmount);
        assertEq(wETH.balanceOf(address(redemption)), depositAmount);
        uint256 wETHInitialMultisigBalance = wETH.balanceOf(redemptionMultisig);

        // Owner can pull ERC20s out
        redemption.recoverERC20(wETH);
        assertEq(wETH.balanceOf(address(redemption)), 0);
        assertEq(wETH.balanceOf(redemptionMultisig), wETHInitialMultisigBalance + depositAmount);
    }

    function testIneligbleHashes() public {
        assertEq(redemption.isHashEligibleForRedemption(1001), false);
        assertEq(redemption.isHashEligibleForRedemption(582), false);
        assertEq(redemption.isHashEligibleForRedemption(236), false);
        assertEq(redemption.isHashEligibleForRedemption(4), true);
    }

    function testRedeemRevert() public {
        // Set up
        address reverter = address(new Reverter());
        vm.prank(dexLabs);
        hashes.transferFrom(dexLabs, reverter, 4);
        vm.prank(redemptionMultisig);
        redemption.setRedemptionStage();

        // Revert at initial redeem
        vm.expectRevert();
        vm.prank(reverter);
        redemption.redeem();

        // More set up
        vm.warp(block.timestamp + redemption.MIN_REDEMPTION_TIME() + 1);
        vm.prank(redemptionMultisig);
        redemption.redeem();
        vm.prank(redemptionMultisig);
        redemption.setPostRedemptionStage();

        // Revert at final redeem
        vm.expectRevert();
        vm.prank(reverter);
        redemption.redeem();
    }
}

contract Reverter {
    receive() external payable {
        revert();
    }
}
