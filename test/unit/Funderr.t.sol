// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "../../src/Funderr.sol";
import "../../src/Errors.sol";
import "../../src/Events.sol";
import {DeployFunderr} from "../../script/DeployFunderr.s.sol";

// TODO: Add modifiers to make campaign created and funded

contract FunderrTest is Test {
    address USER = makeAddr("user");
    address USER_2 = makeAddr("user_2");
    address CAMPAIGN_1_OWNER = makeAddr("campaign1Owner");
    address CAMPAIGN_2_OWNER = makeAddr("campaign2Owner");
    Funderr funderr;

    uint256 constant GOAL = 1 ether;
    uint256 constant DURATION = 1000;
    string constant DEFAULT_TITLE_TEXT = "Test title";
    string constant DEFAULT_DESCRIPTION_TEXT = "Test description";
    uint256 constant STARTING_USER_BALANCE = 100 ether;
    uint256 constant searchCampaignId = 0;

    // Helper functions
    function generateStringOfLength(uint256 length) internal pure returns (string memory) {
        bytes memory result = new bytes(length);

        for (uint256 i = 0; i < length; i++) {
            result[i] = "A";
        }

        return string(result);
    }

    // Setup
    function setUp() external {
        DeployFunderr deployFunderr = new DeployFunderr();
        funderr = deployFunderr.run();

        vm.deal(USER, STARTING_USER_BALANCE);
        vm.deal(USER_2, STARTING_USER_BALANCE);
        vm.deal(CAMPAIGN_1_OWNER, STARTING_USER_BALANCE);
        vm.deal(CAMPAIGN_2_OWNER, STARTING_USER_BALANCE);
    }

    // Test public helper functions
    function testOwnerIsDeployer() public view {
        assertEq(msg.sender, funderr.getOwner());
    }

    function testGetCampaignReturnsDataWhenCampaignExists() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        (
            uint256 campaignId,
            address owner,
            uint256 campaignGoal,
            uint256 deadline,
            uint256 totalContributed,
            bool fundsWithdrawn,
            string memory title,
            string memory descrition
        ) = funderr.getCampaign(searchCampaignId);

        assertEq(searchCampaignId, campaignId);
        assertEq(CAMPAIGN_1_OWNER, owner);
        assertEq(GOAL, campaignGoal);
        assertEq(block.timestamp + DURATION, deadline);
        assertEq(0, totalContributed);
        assertEq(false, fundsWithdrawn);
        assertEq(DEFAULT_TITLE_TEXT, title);
        assertEq(DEFAULT_DESCRIPTION_TEXT, descrition);
    }

    function testGetCampaignFailsWhenCampaignDoesNotExist() public {
        vm.expectRevert(Errors.Funderr__CampaignDoesNotExist.selector);
        funderr.getCampaign(searchCampaignId);
    }

    function testGetCampaingContributionByContributorFailsWhenCampaignDoesNotExist() public {
        vm.expectRevert(Errors.Funderr__CampaignDoesNotExist.selector);
        funderr.getCampaingContributionByContributor(searchCampaignId, CAMPAIGN_1_OWNER);
    }

    function testGetCampaingContributionByContributorReturnsZeroForNonExistentContributor() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        uint256 contributedByUser2 = funderr.getCampaingContributionByContributor(searchCampaignId, USER_2);

        assertEq(0, contributedByUser2);
    }

    // Test public functional functions
    // -- Create campaign
    function testCreateCampaignFailsWhenTitleIsTooLong() public {
        string memory tooLongTitle = generateStringOfLength(funderr.getMaxTitleLength() + 1);

        uint256 createCampaignFee = funderr.getCreateCampaignFee();

        vm.prank(CAMPAIGN_1_OWNER);
        vm.expectRevert(Errors.Funderr__TitleTooLong.selector);
        funderr.createCampaign{value: createCampaignFee}(GOAL, DURATION, tooLongTitle, DEFAULT_DESCRIPTION_TEXT);
    }

    function testCreateCampaignFailsWhenDescriptionIsTooLong() public {
        string memory tooLongDescription = generateStringOfLength(funderr.getMaxDescriptionLength() + 1);

        uint256 createCampaignFee = funderr.getCreateCampaignFee();

        vm.prank(CAMPAIGN_1_OWNER);
        vm.expectRevert(Errors.Funderr__DescriptionTooLong.selector);
        funderr.createCampaign{value: createCampaignFee}(GOAL, DURATION, DEFAULT_TITLE_TEXT, tooLongDescription);
    }

    function testCreateCampaignUpdatesTheCampaignIdList() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        uint256[] memory expected = new uint256[](2);
        expected[0] = 0;
        expected[1] = 1;

        assertEq(expected, funderr.getCampaignsByOwner(CAMPAIGN_1_OWNER));
    }

    function testCreateCampaignCreatesCampaignWithCorrectValues() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        (
            uint256 campaignId,
            address owner,
            uint256 campaignGoal,
            uint256 deadline,
            uint256 totalContributed,
            bool fundsWithdrawn,
            string memory title,
            string memory description
        ) = funderr.getCampaign(searchCampaignId);

        assertEq(searchCampaignId, campaignId);
        assertEq(CAMPAIGN_1_OWNER, owner);
        assertEq(GOAL, campaignGoal);
        assertEq(block.timestamp + DURATION, deadline);
        assertEq(0, totalContributed);
        assertEq(false, fundsWithdrawn);
        assertEq(DEFAULT_TITLE_TEXT, title);
        assertEq(DEFAULT_DESCRIPTION_TEXT, description);
    }

    function testCreateCampaignEmitsCampaignCreatedEvent() public {
        uint256 createCampaignFee = funderr.getCreateCampaignFee();

        vm.expectEmit(true, true, true, true);
        emit Events.CampaignCreated(0, CAMPAIGN_1_OWNER, GOAL, block.timestamp + DURATION);

        vm.prank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: createCampaignFee}(GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT);
    }

    // -- Contribute
    function testContributeFailsWhenCampaignDoesNotExist() public {
        vm.expectRevert(Errors.Funderr__CampaignDoesNotExist.selector);
        funderr.contribute(1);
    }

    function testContributeFailsWhenContributionIsZero() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.expectRevert(Errors.Funderr__ContributionMustBeGreaterThanZero.selector);

        vm.prank(USER);
        funderr.contribute{value: 0}(0);
    }

    function testContributeFailsWhenDeadlineHasPassed() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.warp(block.timestamp + DURATION + 1);
        vm.expectRevert(Errors.Funderr__DeadlinePassed.selector);
        vm.prank(USER);
        funderr.contribute{value: GOAL}(0);
    }

    function testContributeIncreasesContractBalanceByAmount() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        uint256 fundMeBalanceBefore = address(funderr).balance;

        vm.prank(USER);
        funderr.contribute{value: GOAL}(0);

        assertEq(fundMeBalanceBefore + GOAL, address(funderr).balance);
    }

    function testContributeSetsTotalContributionsAndSeparateContributionsCorrectly() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.startPrank(CAMPAIGN_2_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        uint256 fundMeBalanceBefore = address(funderr).balance;

        vm.startPrank(USER);
        funderr.contribute{value: GOAL}(0);
        funderr.contribute{value: GOAL}(0);
        vm.stopPrank();

        vm.startPrank(USER_2);
        funderr.contribute{value: GOAL}(0);
        funderr.contribute{value: GOAL}(1);
        vm.stopPrank();

        (,,,, uint256 totalContributedToCampaign,,,) = funderr.getCampaign(searchCampaignId);

        uint256 contributedByUser = funderr.getCampaingContributionByContributor(searchCampaignId, USER);

        uint256 contributedByUser2 = funderr.getCampaingContributionByContributor(searchCampaignId, USER_2);

        assertEq(fundMeBalanceBefore + GOAL * 4, address(funderr).balance);
        assertEq(GOAL * 3, totalContributedToCampaign);
        assertEq(GOAL * 2, contributedByUser);
        assertEq(GOAL, contributedByUser2);
    }

    function testContributeOwnerCanContribute() public {
        uint256 fundMeBalanceBefore = address(funderr).balance;

        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        funderr.contribute{value: GOAL}(0);
        vm.stopPrank();

        assertEq(fundMeBalanceBefore + GOAL + funderr.getCreateCampaignFee(), address(funderr).balance);
    }

    // -- Withdraw campaign contributions
    function testWithdrawCampaignContributionsOnlyOwnerCanWIthdraw() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.prank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);

        vm.warp(block.timestamp + DURATION + 1);
        vm.prank(USER);
        vm.expectRevert(Errors.Funderr__NotCampaignOwner.selector);
        funderr.withdrawCampaignContributions(searchCampaignId);
    }

    function testWithdrawCampaignContributionsCanWithdrawOnlyAfterDeadline() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.prank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);

        vm.prank(CAMPAIGN_1_OWNER);
        vm.expectRevert(Errors.Funderr__DeadlineNotReached.selector);
        funderr.withdrawCampaignContributions(searchCampaignId);
    }

    function testWithdrawCampaignContributionsCantWithdrawIfNothingWasContributed() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.warp(block.timestamp + DURATION + 1);
        vm.expectRevert(Errors.Funderr__TotalContributionsMustBeGreaterThanZero.selector);
        funderr.withdrawCampaignContributions(searchCampaignId);
        vm.stopPrank();
    }

    function testWithdrawCampaignContributionsCantWithdrawMoreThanOnce() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.prank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);

        vm.startPrank(CAMPAIGN_1_OWNER);
        vm.warp(block.timestamp + DURATION + 1);
        funderr.withdrawCampaignContributions(searchCampaignId);
        vm.expectRevert(Errors.Funderr__FundsAlreadyBeenWithdrawn.selector);
        funderr.withdrawCampaignContributions(searchCampaignId);
        vm.stopPrank();
    }

    function testWithdrawCampaignContributionsCantWithdrawIfGoalNotReached() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL * 2, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.prank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);

        vm.prank(CAMPAIGN_1_OWNER);
        vm.warp(block.timestamp + DURATION + 1);
        vm.expectRevert(Errors.Funderr__GoalNotReached.selector);
        funderr.withdrawCampaignContributions(searchCampaignId);
    }

    function testWithdrawCampaignContributionsSetsWithdrawnFlagToTrue() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.prank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);

        vm.prank(CAMPAIGN_1_OWNER);
        vm.warp(block.timestamp + DURATION + 1);
        funderr.withdrawCampaignContributions(searchCampaignId);

        (,,,,, bool fundsWithdrawn,,) = funderr.getCampaign(searchCampaignId);

        assertEq(true, fundsWithdrawn);
    }

    function testWithdrawCampaignContributionsTransfersTheFundsToOwner() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        uint256 fundMeBalanceBefore = address(funderr).balance;

        vm.prank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);

        uint256 campaign1OwnerBalanceBefore = CAMPAIGN_1_OWNER.balance;
        vm.prank(CAMPAIGN_1_OWNER);
        vm.warp(block.timestamp + DURATION + 1);
        funderr.withdrawCampaignContributions(searchCampaignId);
        uint256 campaign1OwnerBalanceAfter = CAMPAIGN_1_OWNER.balance;

        assertEq(GOAL, campaign1OwnerBalanceAfter - campaign1OwnerBalanceBefore);
        assertEq(fundMeBalanceBefore, address(funderr).balance);
    }

    function testWithdrawCampaignContributionsEmitsEventOnTransfer() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.prank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);

        vm.warp(block.timestamp + DURATION + 1);
        vm.prank(CAMPAIGN_1_OWNER);
        vm.expectEmit(true, true, true, true);
        emit Events.FundsWithdrawn(0, CAMPAIGN_1_OWNER, GOAL);

        funderr.withdrawCampaignContributions(searchCampaignId);
    }

    // -- Refund contributor contributions
    function testRefundContributorContributionsFailsWhenCampaignDoesNotExist() public {
        vm.expectRevert(Errors.Funderr__CampaignDoesNotExist.selector);
        funderr.refundContributorContributions(0);
    }

    function testRefundContributorContributionsCantRefundIfBeforeCampaignDeadline() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.prank(USER);
        vm.expectRevert(Errors.Funderr__DeadlineNotReached.selector);
        funderr.refundContributorContributions(searchCampaignId);
    }

    function testRefundContributorContributionsCantRefundIfUserDidNotContributeAnything() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.warp(block.timestamp + DURATION + 1);
        vm.prank(USER);
        vm.expectRevert(Errors.Funderr__NothingToRefund.selector);
        funderr.refundContributorContributions(searchCampaignId);
    }

    function testRefundContributorContributionsCanRefundImmediatelyIfCampaignDeadlineReachedAndGoalIsNot() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL * 2, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.startPrank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);
        uint256 userBalanceAfterContribution = USER.balance;
        vm.warp(block.timestamp + DURATION + 1);
        funderr.refundContributorContributions(searchCampaignId);
        uint256 userBalanceAfterRefund = USER.balance;
        vm.stopPrank();

        assertEq(GOAL, userBalanceAfterRefund - userBalanceAfterContribution);
    }

    function testRefundContributorContributionsCantRefundIfCampaignGoalHasBeenReachedAndCampaignIsNotStale() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.startPrank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);
        vm.warp(block.timestamp + DURATION + 1);
        vm.expectRevert(Errors.Funderr__CampaignGoalHasBeenReachedAndWithdrawPeriodHasNotExpired.selector);
        funderr.refundContributorContributions(searchCampaignId);
        vm.stopPrank();
    }

    function testRefundContributorContributionsCanRefundIfCampaignIsStale() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.startPrank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);
        uint256 userBalanceAfterContribution = USER.balance;
        vm.warp(block.timestamp + DURATION + funderr.getActiveFundedCampaignWindow() + 1);
        funderr.refundContributorContributions(searchCampaignId);
        uint256 userBalanceAfterRefund = USER.balance;
        vm.stopPrank();

        assertEq(GOAL, userBalanceAfterRefund - userBalanceAfterContribution);
        assertEq(0, funderr.getCampaingContributionByContributor(searchCampaignId, USER));
    }

    function testRefundContributorContributionsCantRefundTwice() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.startPrank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);
        vm.warp(block.timestamp + DURATION + funderr.getActiveFundedCampaignWindow() + 1);
        funderr.refundContributorContributions(searchCampaignId);
        vm.expectRevert(Errors.Funderr__NothingToRefund.selector);
        funderr.refundContributorContributions(searchCampaignId);
        vm.stopPrank();
    }

    function testRefundContributorContributionsCantRefundIfCampaignHasBeenWithdrawn() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.prank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);

        vm.warp(block.timestamp + DURATION + funderr.getActiveFundedCampaignWindow() + 1);

        vm.prank(CAMPAIGN_1_OWNER);
        funderr.withdrawCampaignContributions(searchCampaignId);

        vm.expectRevert(Errors.Funderr__CampaignContributionsHasBeenWithdrawn.selector);

        vm.prank(USER);
        funderr.refundContributorContributions(searchCampaignId);
    }

    function testRefundContributorContributionsEmitsEventOnSuccess() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.startPrank(USER);
        funderr.contribute{value: GOAL}(searchCampaignId);
        vm.warp(block.timestamp + DURATION + funderr.getActiveFundedCampaignWindow() + 1);

        vm.expectEmit(true, true, true, true);
        emit Events.RefundIssued(0, USER, GOAL);

        funderr.refundContributorContributions(searchCampaignId);
        vm.stopPrank();
    }

    // -- Collect fees
    function testCollectFeesCanOnlyBeCalledByOwner() public {
        vm.startPrank(USER);
        vm.expectRevert(Errors.Funderr__OnlyOwner.selector);
        funderr.collectFees();
    }

    function testCollectFeesFailsWhenNothingToCollect() public {
        vm.expectRevert(Errors.Funderr__NoFeesToCollect.selector);
        vm.prank(msg.sender);
        funderr.collectFees();
    }

    function testCollectFeesProperlyUpdatesTotalFeesCollectedAndSendsFundsToOwner() public {
        assertEq(0, funderr.getFeesCollected());

        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        assertEq(funderr.getCreateCampaignFee(), funderr.getFeesCollected());
        uint256 ownerBalanceBefore = address(msg.sender).balance;

        vm.prank(msg.sender);
        funderr.collectFees();

        uint256 ownerBalanceAfter = address(msg.sender).balance;

        assertEq(funderr.getCreateCampaignFee(), ownerBalanceAfter - ownerBalanceBefore);
        assertEq(0, funderr.getFeesCollected());
    }

    function testCollectFeesEmitsEventOnSuccess() public {
        vm.startPrank(CAMPAIGN_1_OWNER);
        funderr.createCampaign{value: funderr.getCreateCampaignFee()}(
            GOAL, DURATION, DEFAULT_TITLE_TEXT, DEFAULT_DESCRIPTION_TEXT
        );
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit Events.FeesCollected(msg.sender, funderr.getCreateCampaignFee());

        vm.prank(msg.sender);
        funderr.collectFees();
    }
}
