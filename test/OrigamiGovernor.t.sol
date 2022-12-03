// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

// our source
import "src/OrigamiGovernor.sol";
import "src/OrigamiMembershipToken.sol";
import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiTimelock.sol";
import "src/governor/SimpleCounting.sol";

// libs
import "@std/Test.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";
import "@oz/utils/Strings.sol";

// interfaces
import "@oz/governance/IGovernor.sol";
import "@oz/governance/extensions/IGovernorTimelock.sol";
import "@oz/access/IAccessControl.sol";

abstract contract GovAddressHelper {
    address public deployer = address(0x1);
    address public owner = address(0x2);
    address public proposer = address(0x3);
    address public voter = address(0x4);
    address public voter2 = address(0x5);
    address public voter3 = address(0x6);
    address public voter4 = address(0x7);
    address public newVoter = address(0x8);
    address public nonMember = address(0x9);
    address public anon = address(0xa);
    address public executor = address(0xc);
    address public govAdmin = address(0xd);
}

// solhint-disable-next-line max-states-count
abstract contract GovHelper is GovAddressHelper, Test {
    OrigamiMembershipToken public memTokenImpl;
    TransparentUpgradeableProxy public memTokenProxy;
    OrigamiMembershipToken public memToken;
    ProxyAdmin public memTokenAdmin;

    OrigamiGovernanceToken public govTokenImpl;
    TransparentUpgradeableProxy public govTokenProxy;
    OrigamiGovernanceToken public govToken;
    ProxyAdmin public govTokenAdmin;

    OrigamiTimelock public timelockImpl;
    TransparentUpgradeableProxy public timelockProxy;
    OrigamiTimelock public timelock;
    ProxyAdmin public timelockAdmin;

    OrigamiGovernor public impl;
    TransparentUpgradeableProxy public proxy;
    OrigamiGovernor public governor;
    ProxyAdmin public admin;

    constructor() {
        vm.startPrank(deployer);

        // deploy membership token via proxy
        memTokenAdmin = new ProxyAdmin();
        memTokenImpl = new OrigamiMembershipToken();
        memTokenProxy = new TransparentUpgradeableProxy(
            address(memTokenImpl),
            address(memTokenAdmin),
            ""
        );
        memToken = OrigamiMembershipToken(address(memTokenProxy));
        memToken.initialize(owner, "Deciduous Tree DAO Membership", "DTDM", "https://example.com/metadata/");

        // deploy timelock via proxy
        timelockAdmin = new ProxyAdmin();
        timelockImpl = new OrigamiTimelock();
        timelockProxy = new TransparentUpgradeableProxy(
            address(timelockImpl),
            address(timelockAdmin),
            ""
        );
        timelock = OrigamiTimelock(payable(timelockProxy));

        // deploy gov token via proxy
        govTokenAdmin = new ProxyAdmin();
        govTokenImpl = new OrigamiGovernanceToken();
        govTokenProxy = new TransparentUpgradeableProxy(
            address(govTokenImpl),
            address(govTokenAdmin),
            ""
        );
        govToken = OrigamiGovernanceToken(address(govTokenProxy));
        govToken.initialize(owner, "Deciduous Tree DAO Membership", "DTDM", 10000000000000000000000000000);

        // deploy governor via proxy
        admin = new ProxyAdmin();
        impl = new OrigamiGovernor();
        proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(admin),
            ""
        );
        governor = OrigamiGovernor(payable(proxy));
        governor.initialize("TestDAOGovernor", timelock, memToken, 91984, 91984, 10, 0, govAdmin);

        // initialize the timelock after we have an address for the governor
        address[] memory proposers = new address[](1);
        proposers[0] = address(governor);
        address[] memory executors = new address[](1);
        executors[0] = address(governor);
        // timelocked for 1 day
        timelock.initialize(7200, proposers, executors);

        vm.stopPrank();

        vm.startPrank(owner);


        // issue the voter some tokens
        memToken.safeMint(voter);
        memToken.safeMint(voter2);
        memToken.safeMint(voter3);
        memToken.safeMint(voter4);
        memToken.safeMint(newVoter);
        govToken.mint(voter, 100000000); // 10000^2
        govToken.mint(voter2, 225000000); // 15000^2
        govToken.mint(voter3, 56250000); // 7500^2
        govToken.mint(voter4, 306250000); // 17500^2
        govToken.mint(nonMember, 56250000);

        // let's travel an arbitrary and small amount of time forward so
        // proposals snapshot after these mints.
        vm.roll(42);
        vm.stopPrank();

        // self-delegate the NFT
        vm.prank(voter);
        memToken.delegate(voter);
        vm.prank(newVoter);
        memToken.delegate(newVoter);
        vm.prank(voter2);
        memToken.delegate(voter2);
        vm.prank(voter3);
        memToken.delegate(voter3);
        vm.prank(voter4);
        memToken.delegate(voter4);

        // selectively self-delegate the gov token for voters past the first one
        vm.prank(voter2);
        govToken.delegate(voter2);
        vm.prank(voter3);
        govToken.delegate(voter3);
        vm.prank(voter4);
        govToken.delegate(voter4);
    }
}

contract OrigamiGovernorTest is GovHelper {
    function testInformationalFunctions() public {
        assertEq(address(governor.timelock()), address(timelock));
        assertEq(governor.name(), "TestDAOGovernor");
        assertEq(governor.votingDelay(), 91984);
        assertEq(governor.version(), "1.1.0");
        assertEq(governor.votingPeriod(), 91984);
        assertEq(governor.proposalThreshold(), 0);
        assertEq(governor.quorumNumerator(), 10);
        assertEq(governor.COUNTING_MODE(), "support=bravo&quorum=for,abstain");
        // just to be clear about the external implementation of the domainSeparator:
        assertEq(
            governor.domainSeparator(),
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(governor.name())),
                    keccak256(bytes(governor.version())),
                    block.chainid,
                    address(governor)
                )
            )
        );
    }
}

contract OrigamiGovernorProposalTest is GovHelper {
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);
    }

    function testCanSubmitProposal() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);

        vm.prank(proposer);
        vm.expectEmit(true, true, true, false, address(governor));
        emit ProposalCreated(
            27805474734109527106678436453108520455405719583396555275526236178632433511344,
            proposer,
            targets,
            values,
            signatures,
            calldatas,
            91985,
            183969,
            "New proposal"
            );
        governor.propose(targets, values, calldatas, "New proposal");
    }

    function testCannotSubmitProposalWithZeroTargets() public {
        targets = new address[](0);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        vm.expectRevert("Governor: empty proposal");
        governor.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitProposalWithTargetsButZeroValues() public {
        targets = new address[](1);
        values = new uint256[](0);
        calldatas = new bytes[](0);
        vm.expectRevert("Governor: invalid proposal length");
        governor.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitProposalWithTargetsButZeroCalldatas() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](0);
        vm.expectRevert("Governor: invalid proposal length");
        governor.propose(targets, values, calldatas, "Empty");
    }

    function testCannotSubmitSameProposalTwice() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        governor.propose(targets, values, calldatas, "New proposal");
        vm.expectRevert("Governor: proposal already exists");
        governor.propose(targets, values, calldatas, "New proposal");
    }

    function testProposalWithParamsTokenMustSupportIVotes() public {
        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        vm.expectRevert("Governor: proposal token must support IVotes");
        governor.proposeWithParams(
            targets,
            values,
            calldatas,
            "New proposal",
            abi.encode(address(timelock), bytes4(keccak256("simpleWeight(uint256)")))
        );
    }
}

contract OrigamiGovernorProposalInformationalTest is GovHelper {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testInformationalFunctions() public {
        // 42 - our arbitrary amount of blocks we have advanced
        assertEq(block.number, 42);
        // 91984 - our default period until voting opens
        assertEq(governor.votingDelay(), 91984);
        // 92026 - current block plus voting delay
        assertEq(governor.proposalSnapshot(proposalId), 92026);
        // 91984 - our default voting period
        assertEq(governor.votingPeriod(), 91984);
        // 184010 - snapshot block plus voting period
        assertEq(governor.proposalDeadline(proposalId), 184010);
        // be explicit about how the proposal hash is derived
        assertEq(governor.hashProposal(targets, values, calldatas, keccak256(bytes("New proposal"))), proposalId);
        //
    }

    function testSupportsInterface() public {
        assertTrue(governor.supportsInterface(type(IGovernor).interfaceId));
        assertTrue(governor.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(governor.supportsInterface(type(IGovernorTimelock).interfaceId));
    }
}

contract OrigamiGovernorProposalVoteTest is GovHelper {
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );

    event ProposalExecuted(uint256 proposalId);

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0x0);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanVoteOnProposalWithDefaultParams() public {
        proposalId = governor.propose(targets, values, calldatas, "Simple Voting Proposal");
        vm.roll(92027);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(governor));
        // our voting weight is 1 here, since this vote uses the membership token
        emit VoteCast(voter, proposalId, 0, 1, "");
        governor.castVote(proposalId, 0);
    }

    function testCanVoteOnProposalWithParams() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.roll(92027);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(voter, proposalId, 1, 100000000, "I like it", params);
        governor.castVoteWithReasonAndParams(proposalId, 1, "I like it", params);
    }

    function testAddressWithoutMembershipTokenCanDelegateToMember() public {
        // self-delegate to get voting power
        vm.prank(nonMember);
        govToken.delegate(newVoter);

        vm.roll(92027);
        vm.prank(newVoter);

        // newVoter has the weight of nonMember's delegated tokens
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(newVoter, proposalId, 0, 56250000, "I vote with their weight!", params);
        governor.castVoteWithReasonAndParams(proposalId, 0, "I vote with their weight!", params);
    }

    function testCanLimitVotingByWeight() public {
        // self-delegate to get voting power
        vm.prank(newVoter);
        govToken.delegate(newVoter);

        vm.roll(92027);
        vm.prank(newVoter);

        // newVoter has correctly self-delegated, but their weight is zero
        vm.expectRevert("Governor: only accounts with delegated voting power can vote");
        governor.castVoteWithReasonAndParams(proposalId, 0, "I don't like it.", params);
    }

    function testCanLimitVotingToMembershipTokenHolders() public {
        vm.roll(92027);
        vm.prank(anon);

        vm.expectRevert("OrigamiGovernor: only members may vote");
        governor.castVoteWithReason(proposalId, 0, "I don't like it.");
    }

    function testCanReviseVote() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        vm.roll(92027);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(voter, proposalId, 1, 100000000, "I like it", params);
        governor.castVoteWithReasonAndParams(proposalId, 1, "I like it", params);

        // our voting system allows us to change our vote at any time,
        // regardless of the value of hasVoted
        assertEq(governor.hasVoted(proposalId, voter), true);

        vm.roll(92028);
        vm.prank(voter);
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(voter, proposalId, 0, 100000000, "I don't like it", params);
        governor.castVoteWithReasonAndParams(proposalId, 0, "I don't like it", params);

        assertEq(governor.hasVoted(proposalId, voter), true);
    }
}

contract OrigamiGovernorProposalQuorumTest is GovHelper {
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testUnreachedQuorumDefeatsProposal() public {
        // travel to proposal voting period completion
        vm.roll(92027 + 91984);
        assertEq(governor.quorum(proposalId), 74375000);
        // there have been no votes, so quorum will not be reached and state will be Defeated
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function testReachedQuorumButDefeated() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // travel to proposal voting period
        vm.roll(92027);

        // vote against the proposal - voter weight exceeds quorum
        vm.prank(voter);
        governor.castVoteWithReasonAndParams(
            proposalId, uint8(SimpleCounting.VoteType.Against), "I don't like it.", params
        );

        // travel to proposal voting period completion
        vm.roll(92027 + 91984);

        // assert vote failed
        (uint256 againstVotes, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertGt(againstVotes, forVotes);

        // quorum is reached, but the proposal is defeated
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function testReachedQuorumAndSucceeded() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // travel to proposal voting period
        vm.roll(92027);

        // vote against the proposal - voter weight exceeds quorum
        vm.prank(voter);
        governor.castVoteWithReasonAndParams(
            proposalId, uint8(SimpleCounting.VoteType.For), "I like it.", params
        );

        // travel to proposal voting period completion
        vm.roll(92027 + 91984);

        // assert vote failed
        (uint256 againstVotes, uint256 forVotes,) = governor.proposalVotes(proposalId);
        assertGt(forVotes, againstVotes);

        // quorum is reached, but the proposal is defeated
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));
    }
}

contract OrigamiGovernorProposalQuadraticVoteTest is GovHelper {
    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("quadraticWeight(uint256)")));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanVoteOnProposalWithQuadraticCounting() public {
        // self-delegate to get voting power
        vm.startPrank(voter);
        govToken.delegate(voter);

        vm.roll(92027);
        vm.expectEmit(true, true, true, true, address(governor));
        emit VoteCastWithParams(voter, proposalId, 1, 100000000, "I like it!", params);
        governor.castVoteWithReasonAndParams(proposalId, 1, "I like it!", params);
    }
}

contract OrigamiGovernorProposalQuadraticVoteResultsTest is GovHelper {
    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0xdead);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("quadraticWeight(uint256)")));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "Quadratic Proposal", params);
    }

    function testQuadraticVotingResultsAreCorrect() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // set block to first eligible voting block
        vm.roll(92027);

        // voter and voter2 collectively have fewer tokens than voter3 by
        // themselves, but quadratic weighting has the effect of making them
        // more powerful together than voter3 alone

        vm.prank(voter);
        governor.castVoteWithReasonAndParams(proposalId, uint8(SimpleCounting.VoteType.For), "I like it!", params);

        vm.prank(voter2);
        governor.castVoteWithReasonAndParams(
            proposalId, uint8(SimpleCounting.VoteType.Against), "This is rubbish!", params
        );

        vm.prank(voter3);
        governor.castVoteWithReasonAndParams(
            proposalId, uint8(SimpleCounting.VoteType.For), "I like it too! It's not rubbish at all!", params
        );

        vm.prank(voter4);
        governor.castVoteWithReasonAndParams(
            proposalId, uint8(SimpleCounting.VoteType.Abstain), "I have no opinion.", params
        );

        vm.roll(92027 + 91984);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);

        assertEq(againstVotes, 15000);
        assertEq(forVotes, 17500);
        assertEq(abstainVotes, 17500);
    }
}

contract OrigamiGovernorSimpleCounting is GovHelper {
    function testCannotSpecifyInvalidWeightStrategy() public {
        vm.expectRevert("Governor: weighting strategy not found");
        governor.applyWeightStrategy(100, bytes4(keccak256("blahdraticWeight(uint256)")));
    }
}

contract OrigamiGovernorLifeCycleTest is GovHelper {
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;
    string[] public signatures;
    uint256 public proposalId;
    bytes public params;
    bytes32 public proposalHash;

    function setUp() public {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        targets[0] = address(0xbeef);
        values[0] = uint256(0x0);
        calldatas[0] = "0x";

        // use the gov token for vote weight
        params = abi.encode(address(govToken), bytes4(keccak256("simpleWeight(uint256)")));
        proposalHash = keccak256(bytes("New proposal"));

        proposalId = governor.proposeWithParams(targets, values, calldatas, "New proposal", params);
    }

    function testCanTransitionProposalThroughToExecution() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.roll(92027);
        vm.prank(voter);
        governor.castVoteWithReasonAndParams(proposalId, 1, "I like it", params);

        // proposal is in the active state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.roll(184011);

        // proposal is in the succeeded state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // console2.log("PR", Strings.toHexString(uint256(timelock.PROPOSER_ROLE())), 32);

        // Enqueue the proposal
        governor.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // advance block timestamp so that it's after the proposal's required queuing time
        vm.warp(7201);
        vm.expectEmit(true, true, true, true, address(governor));
        emit ProposalExecuted(proposalId);
        governor.execute(targets, values, calldatas, proposalHash);

        // advance to the the next block
        vm.roll(184012);

        // proposal is in the executed state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    function testCanTransitionProposalThroughToCancellation() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.roll(92027);
        vm.prank(voter);
        governor.castVoteWithReasonAndParams(proposalId, 1, "I like it", params);

        // proposal is in the active state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.roll(184011);

        // proposal is in the succeeded state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Enqueue the proposal
        governor.queue(targets, values, calldatas, proposalHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // advance block timestamp so that it's just before the proposal's required queuing time
        vm.warp(7200);

        // grant the govAdmin the CANCELLER_ROLE
        vm.startPrank(govAdmin);
        governor.grantRole(governor.CANCELLER_ROLE(), govAdmin);

        vm.expectEmit(true, true, true, true, address(governor));
        emit ProposalCanceled(proposalId);
        governor.cancel(targets, values, calldatas, proposalHash);
        vm.stopPrank();

        // advance to the the next block
        vm.roll(184012);

        // proposal is in the canceled state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Canceled));
    }

    function testCannotQueueIfProposalIsDefeated() public {
        // self-delegate to get voting power
        vm.prank(voter);
        govToken.delegate(voter);

        // proposal is created in the pending state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // advance to the voting period
        vm.roll(92027);
        vm.prank(voter);
        governor.castVoteWithReasonAndParams(proposalId, 0, "I Don't like it", params);

        // proposal is in the active state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // advance to the voting deadline
        vm.roll(184011);

        // proposal is in the succeeded state
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));

        vm.expectRevert("Governor: proposal not successful");
        // Enqueue the proposal
        governor.queue(targets, values, calldatas, proposalHash);
    }
}
