// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Hashes} from "contracts/Hashes.sol";
import {Redemption, IRedemption} from "contracts/redemption/Redemption.sol";
import {DeployRedemption} from "script/DeployRedemption.s.sol";

/// @dev Fuzz test suite for the Hashes DAO redemption contract
contract RedemptionFuzzTest is Test, DeployRedemption {
    ERC20 public wETH;
    Hashes public hashes;

    address public hashHolder0;
    address public hashHolder1;
    address public dexLabs;
    address public deactivatedHolder;
    address public daoWallet;

    modifier prank(address _caller) {
        vm.startPrank(_caller);
        _;
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();

        vm.selectFork(vm.createFork(vm.envString("RPC_URL")));

        hashes = Hashes(0xD07e72b00431af84AD438CA995Fd9a7F0207542d);
        dexLabs = address(0xEE1DDffcb15C00911d0F78c1A1C75C79b77C5d66);

        run();
    }

    /// fuzz over the balance for initial split
    /// fuzz the total number redeemed for second split with no additional deposits
    /// fuzz the total number redeemed for second split with additional deposits after first split
}
