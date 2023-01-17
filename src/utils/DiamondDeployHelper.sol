// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/governor/GovernorCoreFacet.sol";
import "src/governor/GovernorSettingsFacet.sol";
import "src/governor/GovernorTimelockControlFacet.sol";

import "@diamond/facets/DiamondCutFacet.sol";
import "@diamond/facets/DiamondLoupeFacet.sol";
import "@diamond/facets/OwnershipFacet.sol";

/**
 * @author Origami
 * @dev Common functions for the Governor modules.
 * @custom:security-contact contract-security@joinorigami.com
 */
library DiamondDeployHelper {
    function diamondLoupeFacetCut(address diamondLoupeFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory diamondLoupeCut)
    {
        bytes4[] memory diamondLoupeSelectors = new bytes4[](5);
        diamondLoupeSelectors[0] = DiamondLoupeFacet.facetAddress.selector;
        diamondLoupeSelectors[1] = DiamondLoupeFacet.facetAddresses.selector;
        diamondLoupeSelectors[2] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        diamondLoupeSelectors[3] = DiamondLoupeFacet.facets.selector;
        diamondLoupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;
        diamondLoupeCut = IDiamondCut.FacetCut({
            facetAddress: diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: diamondLoupeSelectors
        });
    }

    function ownershipFacetCut(address ownershipFacet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory ownershipCut)
    {
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipFacet.owner.selector;
        ownershipCut = IDiamondCut.FacetCut({
            facetAddress: ownershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });
    }

    function governorCoreFacetCut(GovernorCoreFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorCoreCut)
    {
        bytes4[] memory selectors = new bytes4[](32);
        selectors[0] = facet.CANCELLER_ROLE.selector;
        selectors[1] = facet.DEFAULT_ADMIN_ROLE.selector;
        selectors[2] = facet.EIP712_TYPEHASH.selector;
        selectors[3] = facet.IDEMPOTENT_BALLOT_TYPEHASH.selector;
        selectors[4] = facet.IDEMPOTENT_PROPOSAL_TYPEHASH.selector;
        selectors[5] = facet.castVote.selector;
        selectors[6] = facet.castVoteBySig.selector;
        selectors[7] = facet.castVoteWithReason.selector;
        selectors[8] = facet.castVoteWithReasonBySig.selector;
        selectors[9] = facet.domainSeparatorV4.selector;
        selectors[10] = facet.getRoleAdmin.selector;
        selectors[11] = facet.getVotes.selector;
        selectors[12] = facet.grantRole.selector;
        selectors[13] = facet.hasRole.selector;
        selectors[14] = facet.hasVoted.selector;
        selectors[15] = facet.hashProposal.selector;
        selectors[16] = facet.name.selector;
        selectors[17] = facet.proposalDeadline.selector;
        selectors[18] = facet.proposalSnapshot.selector;
        selectors[19] = facet.proposalVotes.selector;
        selectors[20] = facet.propose.selector;
        selectors[21] = facet.proposeBySig.selector;
        selectors[22] = facet.proposeWithParams.selector;
        selectors[23] = facet.proposeWithParamsBySig.selector;
        selectors[24] = facet.proposeWithTokenAndCountingStrategy.selector;
        selectors[25] = facet.proposeWithTokenAndCountingStrategyBySig.selector;
        selectors[26] = facet.quorum.selector;
        selectors[27] = facet.renounceRole.selector;
        selectors[28] = facet.revokeRole.selector;
        selectors[29] = facet.simpleWeight.selector;
        selectors[30] = facet.state.selector;
        selectors[31] = facet.version.selector;

        governorCoreCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function governorSettingsFacetCut(GovernorSettingsFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorSettingsCut)
    {
        bytes4[] memory selectors = new bytes4[](18);
        selectors[0] = facet.defaultCountingStrategy.selector;
        selectors[1] = facet.defaultProposalToken.selector;
        selectors[2] = facet.governanceToken.selector;
        selectors[3] = facet.membershipToken.selector;
        selectors[4] = facet.proposalThreshold.selector;
        selectors[5] = facet.proposalThresholdToken.selector;
        selectors[6] = facet.quorumNumerator.selector;
        selectors[7] = facet.setDefaultCountingStrategy.selector;
        selectors[8] = facet.setDefaultProposalToken.selector;
        selectors[9] = facet.setGovernanceToken.selector;
        selectors[10] = facet.setMembershipToken.selector;
        selectors[11] = facet.setProposalThreshold.selector;
        selectors[12] = facet.setProposalThresholdToken.selector;
        selectors[13] = facet.setQuorumNumerator.selector;
        selectors[14] = facet.setVotingDelay.selector;
        selectors[15] = facet.setVotingPeriod.selector;
        selectors[16] = facet.votingDelay.selector;
        selectors[17] = facet.votingPeriod.selector;

        governorSettingsCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function governorTimelockControlFacetCut(GovernorTimelockControlFacet facet)
        internal
        pure
        returns (IDiamondCut.FacetCut memory governorTimelockControlCut)
    {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = facet.cancel.selector;
        selectors[1] = facet.execute.selector;
        selectors[2] = facet.proposalEta.selector;
        selectors[3] = facet.queue.selector;
        selectors[4] = facet.timelock.selector;
        selectors[5] = facet.updateTimelock.selector;

        governorTimelockControlCut = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }
}
