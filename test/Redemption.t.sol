// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Hashes} from "contracts/Hashes.sol";
import {HashesDAO} from "contracts/HashesDAO.sol";
import {Redemption} from "contracts/redemption/Redemption.sol";
import {DeployRedemption} from "script/DeployRedemption.s.sol";

/// @dev Test suite for the Hashes DAO redemption contract
contract RedemptionTests is Test, DeployRedemption {
    ERC20 public wETH;
    Hashes public hashes;
    HashesDAO public hashesDAO;

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
        hashesDAO = HashesDAO(payable(0xbD3Af18e0b7ebB30d49B253Ab00788b92604552C));

        //hashHolder0 = address(0x391b4A553551606Bbd1CDee08A0fA31f8548F3DC);
        //hashHolder1 = address(0xd958bBEfB7513b083A74962e49f759745f36B008);
        dexLabs = address(0xEE1DDffcb15C00911d0F78c1A1C75C79b77C5d66);
        deactivatedHolder = address(0xAFcd6E3D6B8E87722eD8d5a598e811672A462a9d);
        daoWallet = address(0x391b4A553551606Bbd1CDee08A0fA31f8548F3DC);

        vm.deal(redemptionMultisig, 350 ether);
        run();

        vm.startPrank(redemptionMultisig);
        (bool s,) = address(redemption).call{value: 350 ether}("");
        require(s);
        redemption.setRedemptionStage();
        vm.stopPrank();
    }

    function testInit() public prank(dexLabs) {
        uint256 balanceBefore = dexLabs.balance;

        redemption.redeem();

        uint256 balanceAfterA = dexLabs.balance;
        assertGt(balanceAfterA, balanceBefore);

        redemption.redeem();

        uint256 balanceAfterB = dexLabs.balance;
        assertEq(balanceAfterB, balanceAfterA);
    }
}
