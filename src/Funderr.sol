// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO: Consolidate all errors/reverts into modifiers
// TODO: Add small fee to start a campaign for profitability and also prevent campaign spam attacks
// TODO: Add contributed to campaigns mapping
// TODO: Add campaign URL (?)
// TODO: Move errors into separate file

contract Funderr {
    // Errors

    error Funderr__CampaignDoesNotExist();
    error Funderr__ContributionMustBeGreaterThanZero();
    error Funderr__DeadlinePassed();
    error Funderr__DeadlineNotReached();
    error Funderr__OnlyOwner();
    error Funderr__NotCampaignOwner();
    error Funderr__TotalContributionsMustBeGreaterThanZero();
    error Funderr__FundsAlreadyBeenWithdrawn();
    error Funderr__WithdrawContributionsCallFailed();
    error Funderr__GoalNotReached();
    error Funderr__NothingToRefund();
    error Funderr__RefundContributionCallFailed();
    error Funderr__CampaignGoalHasBeenReachedAndWithdrawPeriodHasNotExpired();
    error Funderr__CampaignContributionsHasBeenWithdrawn();
    error Funderr__TitleTooLong();
    error Funderr__DescriptionTooLong();

    // Structs

    struct Campaign {
        address owner;
        uint256 goal;
        uint256 deadline;
        uint256 totalContributed;
        bool fundsWithdrawn;
        string title;
        string description;
        mapping(address => uint256) contributions;
    }

    // State variables

    uint256 private campaignIdCounter;
    address private immutable i_owner;
    uint256 private immutable i_activeFundedCampaignWindow;
    uint256 private immutable i_maxTitleLength;
    uint256 private immutable i_maxDescriptionLength;
    mapping(uint256 => Campaign) private campaigns;
    mapping(address => uint256[]) private campaignsByOwner;

    // Events

    event CampaignCreated(
        uint256 campaignId,
        address indexed owner,
        uint256 goal,
        uint256 deadline
    );

    event ContributionReceived(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed owner,
        uint256 amount
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    // Modifiers

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert Funderr__OnlyOwner();
        _;
    }

    modifier onlyCampaignOwner(uint256 campaignId) {
        if (msg.sender != campaigns[campaignId].owner) {
            revert Funderr__NotCampaignOwner();
        }
        _;
    }

    modifier campaignExists(uint256 campaignId) {
        if (campaigns[campaignId].owner == address(0)) {
            revert Funderr__CampaignDoesNotExist();
        }
        _;
    }

    modifier afterDeadline(uint256 campaignId) {
        if (block.timestamp > campaigns[campaignId].deadline) {
            revert Funderr__DeadlinePassed();
        }
        _;
    }

    modifier beforeDeadline(uint256 campaignId) {
        if (block.timestamp <= campaigns[campaignId].deadline) {
            revert Funderr__DeadlineNotReached();
        }
        _;
    }

    modifier titleTooLong(string memory title) {
        if (bytes(title).length > i_maxTitleLength)
            revert Funderr__TitleTooLong();
        _;
    }

    modifier descriptionTooLong(string memory description) {
        if (bytes(description).length > i_maxDescriptionLength)
            revert Funderr__DescriptionTooLong();
        _;
    }

    // Constructor

    constructor(
        uint256 maxTitleLength,
        uint256 maxDescriptionLength,
        uint256 activeFundedCampaignWindow
    ) {
        i_owner = msg.sender;
        i_maxTitleLength = maxTitleLength;
        i_maxDescriptionLength = maxDescriptionLength;
        i_activeFundedCampaignWindow = activeFundedCampaignWindow;
    }

    // Public functional functions

    function createCampaign(
        uint256 goalInWei,
        uint256 durationInSeconds,
        string memory title,
        string memory description
    ) external titleTooLong(title) descriptionTooLong(description) {
        uint256 campaignId = campaignIdCounter++;
        Campaign storage c = campaigns[campaignId];

        c.owner = msg.sender;
        c.goal = goalInWei;
        c.deadline = block.timestamp + durationInSeconds;
        c.title = title;
        c.description = description;

        campaignsByOwner[msg.sender].push(campaignId);

        emit CampaignCreated(campaignId, c.owner, c.goal, c.deadline);
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

    function getActiveFundedCampaignWindow() external view returns (uint256) {
        return i_activeFundedCampaignWindow;
    }

    function getMaxTitleLength() external view returns (uint256) {
        return i_maxTitleLength;
    }

    function getMaxDescriptionLength() external view returns (uint256) {
        return i_maxDescriptionLength;
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
