// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Errors.sol";

/**
 * @title Modifiers
 * @notice Custom modifiers for the Funderr contract
 */
abstract contract Modifiers is Errors {
    // Campaign struct needed for modifiers
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

    // Abstract state variables that must be implemented by inheriting contract
    mapping(uint256 => Campaign) internal campaigns;
    uint256 internal immutable i_maxTitleLength;
    uint256 internal immutable i_maxDescriptionLength;
    address internal immutable i_owner;

    // Access control modifiers
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

    // Campaign validation modifiers
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

    // Input validation modifiers
    modifier titleTooLong(string memory title) {
        if (bytes(title).length > i_maxTitleLength) {
            revert Funderr__TitleTooLong();
        }
        _;
    }

    modifier descriptionTooLong(string memory description) {
        if (bytes(description).length > i_maxDescriptionLength) {
            revert Funderr__DescriptionTooLong();
        }
        _;
    }
}
