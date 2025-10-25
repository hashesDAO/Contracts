// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

/// @title Hashes Redemption
/// @notice This contract...
interface IRedemption {
    enum Stages {
        PreRedemption,
        Redemption,
        PostRedemption
    }

    error WrongStage();

    error TransferFailed();

    error MinRedemptionTime();
}
