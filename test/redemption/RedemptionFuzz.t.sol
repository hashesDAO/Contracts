// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {StdStorage, Test, stdStorage} from "forge-std/Test.sol";
import {Hashes} from "contracts/Hashes.sol";
import {Redemption} from "contracts/redemption/Redemption.sol";
import {DeployRedemption} from "script/DeployRedemption.s.sol";

/// @dev Fuzz test suite for the Hashes DAO redemption contract
contract RedemptionFuzzTest is Test, DeployRedemption {
    using stdStorage for StdStorage;

    Hashes public hashes;

    modifier prank(address _caller) {
        vm.startPrank(_caller);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();

        hashes = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);
        run();
    }

    function testFuzzInitialRedemptionPerHash(uint256 _balance) public prank(redemptionMultisig) {
        _balance = bound(_balance, 0, 1_000 ether);
        deal(address(redemption), _balance);
        redemption.setRedemptionStage();
        assertLe(redemption.INITIAL_ELIGIBLE_HASHES_TOTAL() * redemption.redemptionPerHash(), _balance);
    }

    function testFuzzFinalRedemptionPerHash(uint256 _balance, uint256 _redeemed) public prank(redemptionMultisig) {
        uint256 total = redemption.INITIAL_ELIGIBLE_HASHES_TOTAL();
        _balance = bound(_balance, 0, total * 1e18);
        _redeemed = bound(_redeemed, 1, total);

        // Redemption Stage
        deal(address(redemption), _balance);
        redemption.setRedemptionStage();

        uint256 initialRedemptionHash = redemption.redemptionPerHash();
        uint256 initialETHWithdrawn = _balance - (_redeemed * initialRedemptionHash);
        assertLe(total * initialRedemptionHash, _balance);

        stdstore.target(address(redemption)).sig("totalNumberRedeemed()").checked_write(_redeemed);
        deal(address(redemption), initialETHWithdrawn);

        // PostRedemption Stage
        vm.warp(block.timestamp + redemption.MIN_REDEMPTION_TIME() + 1);
        redemption.setPostRedemptionStage();
        assertLe(_redeemed * redemption.redemptionPerHash(), initialETHWithdrawn);
    }

    function testFuzzFinalRedemptionPerHashWithAddition(uint256 _balance, uint256 _redeemed, uint256 _addition)
        public
        prank(redemptionMultisig)
    {
        uint256 total = redemption.INITIAL_ELIGIBLE_HASHES_TOTAL();
        _balance = bound(_balance, 0, total * 1e18);
        _redeemed = bound(_redeemed, 1, total);
        _addition = bound(_addition, 0, total * 1e18);

        // Redemption Stage
        deal(address(redemption), _balance);
        redemption.setRedemptionStage();

        // PostRedemption Stage
        uint256 initialRedemptionHash = redemption.redemptionPerHash();
        uint256 initialETHWithdrawn = _balance - (_redeemed * initialRedemptionHash);
        assertLe(total * initialRedemptionHash, _balance);

        stdstore.target(address(redemption)).sig("totalNumberRedeemed()").checked_write(_redeemed);
        deal(address(redemption), initialETHWithdrawn + _addition);

        // PostRedemption Stage
        vm.warp(block.timestamp + redemption.MIN_REDEMPTION_TIME() + 1);
        redemption.setPostRedemptionStage();
        assertLe(_redeemed * redemption.redemptionPerHash(), initialETHWithdrawn + _addition);
    }
}
