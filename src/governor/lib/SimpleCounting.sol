//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {GovernorQuorum} from "src/governor/lib/GovernorQuorum.sol";
import {TokenWeightStrategy} from "src/governor/lib/TokenWeightStrategy.sol";
import {Voting} from "src/governor/lib/Voting.sol";
import {GovernorStorage} from "src/utils/GovernorStorage.sol";

/**
 * @title Simple Counting strategy
 * @author Origami
 * @notice Implements swappable counting strategies at the proposal level.
 * @custom:security-contact contract-security@joinorigami.com
 */
library SimpleCounting {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    /**
     * @notice a required function from IGovernor that declares what Governor style we support and how we derive quorum.
     * @dev See {IGovernor-COUNTING_MODE}.
     * @return string indicating the counting mode.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() internal pure returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @notice sets the vote for a given proposal and account in a manner that is compatible with SimpleCounting strategies.
     * @param proposalId the proposal to record the vote for
     * @param account the account that is voting
     * @param support the VoteType that the account is voting
     * @param weight the weight of their vote as of the proposal snapshot
     */
    function setVote(uint256 proposalId, address account, uint8 support, uint256 weight) internal {
        bytes4 weightingSelector = GovernorStorage.proposal(proposalId).countingStrategy;

        uint256 calculatedWeight = TokenWeightStrategy.applyStrategy(weight, weightingSelector);
        Voting.setVote(proposalId, account, abi.encode(VoteType(support), weight, calculatedWeight));
    }

    /**
     * @dev used by OrigamiGovernor when totaling proposal outcomes. We defer tallying so that individual voters can change their vote during the voting period.
     * @param proposalId the id of the proposal to retrieve voters for.
     * @return the list of voters for the proposal.
     */
    function getProposalVoters(uint256 proposalId) internal view returns (address[] memory) {
        return GovernorStorage.proposalVoters(proposalId);
    }

    /**
     * @dev decodes the vote for a given proposal and voter.
     * @param proposalId the id of the proposal.
     * @param voter the address of the voter.
     * @return the vote type, the weight of the vote, and the weight of the vote with the weighting strategy applied.
     */
    function getVote(uint256 proposalId, address voter) internal view returns (VoteType, uint256, uint256) {
        return abi.decode(Voting.getVote(proposalId, voter), (VoteType, uint256, uint256));
    }

    /**
     * @notice returns the current votes for, against, or abstaining for a given proposal. Once the voting period has lapsed, this is used to determine the outcome.
     * @dev this delegates weight calculation to the strategy specified in the params
     * @param proposalId the id of the proposal to get the votes for.
     * @return againstVotes - the number of votes against the proposal.
     * @return forVotes - the number of votes for the proposal.
     * @return abstainVotes - the number of votes abstaining from the vote.
     */
    function simpleProposalVotes(uint256 proposalId)
        internal
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    {
        address[] memory voters = GovernorStorage.proposalVoters(proposalId);
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];
            (VoteType support,, uint256 calculatedWeight) = getVote(proposalId, voter);
            if (support == VoteType.Abstain) {
                abstainVotes += calculatedWeight;
            } else if (support == VoteType.For) {
                forVotes += calculatedWeight;
            } else if (support == VoteType.Against) {
                againstVotes += calculatedWeight;
            }
        }
    }

    /**
     * @dev implementation of {Governor-quorumReached} that is compatible with the SimpleCounting strategies.
     * @param proposalId the id of the proposal to check.
     * @return boolean - true if the quorum has been reached.
     */
    function quorumReached(uint256 proposalId) internal view returns (bool) {
        (, uint256 forVotes, uint256 abstainVotes) = simpleProposalVotes(proposalId);
        bytes4 countingStrategy = GovernorStorage.proposal(proposalId).countingStrategy;
        return TokenWeightStrategy.applyStrategy(GovernorQuorum.quorum(proposalId), countingStrategy)
            <= forVotes + abstainVotes;
    }

    /**
     * @dev returns the winning option for a given proposal.
     * @param proposalId the id of the proposal to check.
     * @return VoteType - the winning option.
     */
    function winningOption(uint256 proposalId) internal view returns (VoteType) {
        (uint256 againstVotes, uint256 forVotes,) = simpleProposalVotes(proposalId);
        if (forVotes >= againstVotes) {
            return VoteType.For;
        } else {
            return VoteType.Against;
        }
    }

    /**
     * @dev returns true if the vote succeeded.
     * @param proposalId the id of the proposal to check.
     * @return boolean - true if the vote succeeded.
     */
    function voteSucceeded(uint256 proposalId) internal view returns (bool) {
        return winningOption(proposalId) == VoteType.For;
    }
}
