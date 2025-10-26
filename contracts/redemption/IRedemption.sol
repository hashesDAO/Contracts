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

    event Deposit(address _user, uint256 _amount);
    event Redeemed(address _user, uint256 _amount);
    event StageSet(Stages _stage);
}
