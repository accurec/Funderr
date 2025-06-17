// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Events
 * @notice Events for the Funderr contract
 */
contract Events {
    // Campaign events
    event CampaignCreated(
        uint256 indexed campaignId,
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

    // Fee collection events
    event FeesCollected(address indexed collector, uint256 amount);
}
