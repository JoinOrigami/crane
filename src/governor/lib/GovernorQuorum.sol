// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/utils/GovernorStorage.sol";

import "@oz/governance/utils/IVotes.sol";

/**
 * @title Origami Governor Quorum shared functions
 * @author Origami
 * @custom:security-contact contract-security@joinorigami.com
 */
library GovernorQuorum {
    /**
     * @dev Returns the quorum numerator for a specific proposalId. This value is set from global config at the time of proposal creation.
     */
    function quorumNumerator(uint256 proposalId) internal view returns (uint128) {
        return GovernorStorage.proposal(proposalId).quorumNumerator;
    }

    /**
     * @dev Returns the quorum denominator. Defaults to 100, but may be overridden.
     */
    function quorumDenominator() internal pure returns (uint128) {
        return 100;
    }

    /**
     * @dev Returns the quorum for a specific proposal's counting token as of its time of creation, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 proposalId) internal view returns (uint256) {
        address proposalToken = GovernorStorage.proposal(proposalId).proposalToken;
        uint256 snapshot = GovernorStorage.proposal(proposalId).snapshot;
        uint256 supply = IVotes(proposalToken).getPastTotalSupply(snapshot);
        return (supply * quorumNumerator(proposalId)) / quorumDenominator();
    }
}
