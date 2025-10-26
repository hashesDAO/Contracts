// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Test} from "forge-std/Test.sol";
import {Hashes} from "contracts/Hashes.sol";
import {Redemption, IRedemption} from "contracts/redemption/Redemption.sol";
import {DeployRedemption} from "script/DeployRedemption.s.sol";

/// @dev Fuzz test suite for the Hashes DAO redemption contract
contract RedemptionFuzzTest is Test, DeployRedemption {
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

    /// fuzz over the balance for initial split
    /// fuzz the total number redeemed for second split with no additional deposits
    /// fuzz the total number redeemed for second split with additional deposits after first split
}
