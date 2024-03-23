// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Hashes} from "../contracts/Hashes.sol";
import {HashesDAO} from "../contracts/HashesDAO.sol";
import {Stages, Redemption} from "../contracts/Redemption.sol";

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
        hashHolder0 = address(0xc37AEDFd7cC5d2f8Cf04885077555ff4524CF726);
        hashHolder1 = address(0xd958bBEfB7513b083A74962e49f759745f36B008);
        dexLabs = address(0xEE1DDffcb15C00911d0F78c1A1C75C79b77C5d66);
        deactivatedHolder = address(0xAFcd6E3D6B8E87722eD8d5a598e811672A462a9d);
        daoWallet = address(0x391b4A553551606Bbd1CDee08A0fA31f8548F3DC);

        /// Award the redemption multisig a DAO hash to expedite stage jumps
        vm.startPrank(hashHolder0);
        hashes.transferFrom(hashHolder0, address(redemptionMultisig), 706);
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
    }

    /// @dev Tests constants and owner
    function testInitialisation() public {
        assertEq(address(redemption.WETH()), address(wETH));
        assertEq(address(redemption.HASHES()), address(hashes));
        assertEq(redemption.MINDEPOSITAMOUNT(), 100);
        assertEq(redemption.MINPOSTREDEMPTIONAMOUNT(), 1);
        assertEq(redemption.MINREDEMPTIONTIME(), 180 days);
        assertEq(redemption.INITIALNUMBEROFELIGIBLEHASHES(), 818);
        assertEq(redemption.owner(), redemptionMultisig);
    }

    /// PREREDEMPTION ///

    /// @dev Tests PreRedemption Stage fail conditions - make redundant
    function testExternalPreRedemptionFailConditions() public prank(hashHolder0) {

        vm.expectRevert("Redemption: Must be in post-redemption stage");
        redemption.postRedeem();
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


        vm.stopPrank();

        /// Non-Redemption stage - PostRedemption
        vm.startPrank(redemptionMultisig);
        _setPostRedemptionStage();
        vm.stopPrank();

        vm.startPrank(hashHolder0);
        //vm.expectRevert("Redemption: asdas");
        //redemption.
        vm.stopPrank();
    }

    /// @dev Tests the Redeem function sucess conditions
    function testRedeemSuccess(uint256 _amount) public {
        vm.startPrank(redemptionMultisig);
        _setRedemptionStage(_amount);
        vm.stopPrank();

        vm.startPrank(hashHolder0);
        
        /// success

        vm.stopPrank();
    }

    /// a successful redeem

    /// POSTREDEMPTION ///

    function testPostRedeem() public {

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
        vm.expectRevert("Redemption: Must deposit at least 100 WETH");
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

    function testSetPostRedemptionStage() public prank(redemptionMultisig) {

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
        set[0] = 706;

        hashes.approve(address(redemption), 706);
        redemption.redeem(set);

        vm.warp(redemption.redemptionSetTime() + redemption.MINREDEMPTIONTIME() + 1);
        redemption.setPostRedemptionStage();
    }

    /// @dev Must be called by Redemption Multisig
    /// Preedemption -> PostRedemption
    function _setRedemptionAndPostRedemptionStage(uint256 _amount) internal {

    }
}