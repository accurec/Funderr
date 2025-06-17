// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Errors.sol";
import "./Modifiers.sol";
import "./Events.sol";

// TODO: Add contributed to campaigns mapping
// TODO: Add campaign URL (?)

contract Funderr is Errors, Modifiers, Events {
    // State variables
    uint256 private campaignIdCounter;
    uint256 private feesCollected;
    uint256 private immutable i_activeFundedCampaignWindow;
    uint256 private immutable i_createCampaignFee;
    mapping(address => uint256[]) private campaignsByOwner;

    // Constructor
    constructor(
        uint256 maxTitleLength,
        uint256 maxDescriptionLength,
        uint256 activeFundedCampaignWindow,
        uint256 createCampaignFee
    ) {
        i_owner = msg.sender;
        i_maxTitleLength = maxTitleLength;
        i_maxDescriptionLength = maxDescriptionLength;
        i_activeFundedCampaignWindow = activeFundedCampaignWindow;
        i_createCampaignFee = createCampaignFee;
    }

    // Public functional functions
    function createCampaign(
        uint256 goalInWei,
        uint256 durationInSeconds,
        string memory title,
        string memory description
    ) external payable titleTooLong(title) descriptionTooLong(description) {
        if (msg.value != i_createCampaignFee) {
            revert Funderr__CreateCampaignFeeNotPaid();
        }

        uint256 campaignId = campaignIdCounter++;
        Campaign storage c = campaigns[campaignId];

        c.owner = msg.sender;
        c.goal = goalInWei;
        c.deadline = block.timestamp + durationInSeconds;
        c.title = title;
        c.description = description;

        campaignsByOwner[msg.sender].push(campaignId);
        feesCollected += i_createCampaignFee;

        emit CampaignCreated(campaignId, c.owner, c.goal, c.deadline);
    }

    function collectFees() external onlyOwner {
        if (feesCollected == 0) revert Funderr__NoFeesToCollect();

        uint256 feesToTransfer = feesCollected;
        feesCollected = 0;

        (bool callSuccess, ) = payable(msg.sender).call{value: feesToTransfer}(
            ""
        );

        if (!callSuccess) revert Funderr__CollectFeesCallFailed();

        emit FeesCollected(msg.sender, feesToTransfer);
    }

    function contribute(
        uint256 campaignId
    ) external payable campaignExists(campaignId) afterDeadline(campaignId) {
        if (msg.value == 0) revert Funderr__ContributionMustBeGreaterThanZero();

        Campaign storage c = campaigns[campaignId];

        c.contributions[msg.sender] += msg.value;
        c.totalContributed += msg.value;

        emit ContributionReceived(campaignId, msg.sender, msg.value);
    }

    function withdrawCampaignContributions(
        uint256 campaignId
    ) external onlyCampaignOwner(campaignId) beforeDeadline(campaignId) {
        Campaign storage c = campaigns[campaignId];

        if (c.totalContributed == 0) {
            revert Funderr__TotalContributionsMustBeGreaterThanZero();
        }

        if (c.totalContributed < c.goal) revert Funderr__GoalNotReached();

        if (c.fundsWithdrawn) revert Funderr__FundsAlreadyBeenWithdrawn();

        c.fundsWithdrawn = true;

        (bool callSuccess, ) = payable(msg.sender).call{
            value: c.totalContributed
        }("");

        if (!callSuccess) revert Funderr__WithdrawContributionsCallFailed();

        emit FundsWithdrawn(campaignId, c.owner, c.totalContributed);
    }

    function refundContributorContributions(
        uint256 campaignId
    ) external campaignExists(campaignId) beforeDeadline(campaignId) {
        Campaign storage c = campaigns[campaignId];

        if (c.contributions[msg.sender] == 0) revert Funderr__NothingToRefund();

        if (c.fundsWithdrawn) {
            revert Funderr__CampaignContributionsHasBeenWithdrawn();
        }

        if (
            c.totalContributed >= c.goal &&
            block.timestamp <= c.deadline + i_activeFundedCampaignWindow
        ) {
            revert Funderr__CampaignGoalHasBeenReachedAndWithdrawPeriodHasNotExpired();
        }

        uint256 amountToRefund = c.contributions[msg.sender];
        c.contributions[msg.sender] = 0;

        (bool callSuccess, ) = payable(msg.sender).call{value: amountToRefund}(
            ""
        );

        if (!callSuccess) revert Funderr__RefundContributionCallFailed();

        emit RefundIssued(campaignId, msg.sender, amountToRefund);
    }

    // Public helper functions
    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getCampaignIdCounter() external view returns (uint256) {
        return campaignIdCounter;
    }

    function getFeesCollected() external view returns (uint256) {
        return feesCollected;
    }

    function getActiveFundedCampaignWindow() external view returns (uint256) {
        return i_activeFundedCampaignWindow;
    }

    function getMaxTitleLength() external view returns (uint256) {
        return i_maxTitleLength;
    }

    function getMaxDescriptionLength() external view returns (uint256) {
        return i_maxDescriptionLength;
    }

    function getCreateCampaignFee() external view returns (uint256) {
        return i_createCampaignFee;
    }

    function getCampaign(
        uint256 campaignId
    )
        external
        view
        campaignExists(campaignId)
        returns (
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            bool,
            string memory,
            string memory
        )
    {
        Campaign storage c = campaigns[campaignId];

        return (
            campaignId,
            c.owner,
            c.goal,
            c.deadline,
            c.totalContributed,
            c.fundsWithdrawn,
            c.title,
            c.description
        );
    }

    function getCampaingContributionByContributor(
        uint256 campaignId,
        address contributor
    ) external view campaignExists(campaignId) returns (uint256) {
        return campaigns[campaignId].contributions[contributor];
    }

    function getCampaignsByOwner(
        address owner
    ) external view returns (uint256[] memory) {
        return campaignsByOwner[owner];
    }

    // TODO:
    // function getContributedCampaignsByContributor(
    //     address contributor
    // ) external view returns (uint256[] memory) {
    //     return contributedCampaignsByContributor[contributor];
    // }
}
