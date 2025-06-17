// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Errors
 * @notice Custom errors for the Funderr contract
 */
contract Errors {
    // Campaign create and contribute errors
    error Funderr__CampaignDoesNotExist();
    error Funderr__ContributionMustBeGreaterThanZero();
    error Funderr__DeadlinePassed();
    error Funderr__DeadlineNotReached();
    error Funderr__TotalContributionsMustBeGreaterThanZero();
    error Funderr__GoalNotReached();
    error Funderr__NothingToRefund();
    error Funderr__CampaignGoalHasBeenReachedAndWithdrawPeriodHasNotExpired();
    error Funderr__CampaignContributionsHasBeenWithdrawn();
    error Funderr__TitleTooLong();
    error Funderr__DescriptionTooLong();
    error Funderr__CreateCampaignFeeNotPaid();

    // Access control errors
    error Funderr__OnlyOwner();
    error Funderr__NotCampaignOwner();

    // Withdrawal and refund errors
    error Funderr__FundsAlreadyBeenWithdrawn();
    error Funderr__WithdrawContributionsCallFailed();
    error Funderr__RefundContributionCallFailed();

    // Fee collection errors
    error Funderr__NoFeesToCollect();
    error Funderr__CollectFeesCallFailed();
}
