// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Script} from "forge-std/Script.sol";
import {Redemption} from "contracts/redemption/Redemption.sol";

contract DeployRedemption is Script {
    address public redemptionMultisig;
    uint256[] public excludedIds;
    Redemption public redemption;

    function setUp() public virtual {
        redemptionMultisig = 0x29d3F32e88D734264f5AB4284B9b05AB3Bb432AF;
        excludedIds = new uint256[](67);
        excludedIds[0] = 236;
        excludedIds[1] = 440;
        excludedIds[2] = 220;
        excludedIds[3] = 818;
        excludedIds[4] = 461;
        excludedIds[5] = 786;
        excludedIds[6] = 280;
        excludedIds[7] = 268;
        excludedIds[8] = 185;
        excludedIds[9] = 314;
        excludedIds[10] = 938;
        excludedIds[11] = 637;
        excludedIds[12] = 393;
        excludedIds[13] = 835;
        excludedIds[14] = 837;
        excludedIds[15] = 291;
        excludedIds[16] = 659;
        excludedIds[17] = 729;
        excludedIds[18] = 352;
        excludedIds[19] = 287;
        excludedIds[20] = 982;
        excludedIds[21] = 965;
        excludedIds[22] = 305;
        excludedIds[23] = 958;
        excludedIds[24] = 585;
        excludedIds[25] = 520;
        excludedIds[26] = 845;
        excludedIds[27] = 844;
        excludedIds[28] = 750;
        excludedIds[29] = 506;
        excludedIds[30] = 614;
        excludedIds[31] = 634;
        excludedIds[32] = 807;
        excludedIds[33] = 759;
        excludedIds[34] = 960;
        excludedIds[35] = 873;
        excludedIds[36] = 678;
        excludedIds[37] = 836;
        excludedIds[38] = 737;
        excludedIds[39] = 828;
        excludedIds[40] = 866;
        excludedIds[41] = 718;
        excludedIds[42] = 599;
        excludedIds[43] = 533;
        excludedIds[44] = 687;
        excludedIds[45] = 920;
        excludedIds[46] = 590;
        excludedIds[47] = 595;
        excludedIds[48] = 584;
        excludedIds[49] = 618;
        excludedIds[50] = 918;
        excludedIds[51] = 512;
        excludedIds[52] = 531;
        excludedIds[53] = 610;
        excludedIds[54] = 290;
        excludedIds[55] = 574;
        excludedIds[56] = 754;
        excludedIds[57] = 791;
        excludedIds[58] = 860;
        excludedIds[59] = 955;
        excludedIds[60] = 701;
        excludedIds[61] = 740;
        excludedIds[62] = 577;
        excludedIds[63] = 250;
        excludedIds[64] = 195;
        excludedIds[65] = 182;
        excludedIds[66] = 926;
    }

    function run() public {
        vm.startBroadcast();
        redemption = new Redemption(excludedIds, redemptionMultisig);
        vm.stopBroadcast();
    }
}

