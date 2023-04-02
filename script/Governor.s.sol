// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {OrigamiTimelockController} from "src/OrigamiTimelockController.sol";
import {GovernorCoreFacet} from "src/governor/GovernorCoreFacet.sol";
import {GovernorSettingsFacet} from "src/governor/GovernorSettingsFacet.sol";
import {GovernorTimelockControlFacet} from "src/governor/GovernorTimelockControlFacet.sol";
import {GovernorDiamondInit} from "src/utils/GovernorDiamondInit.sol";
import {DiamondDeployHelper} from "src/utils/DiamondDeployHelper.sol";

import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "@diamond/facets/DiamondCutFacet.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {OwnershipFacet} from "@diamond/facets/OwnershipFacet.sol";

import {Script} from "@std/Script.sol";
import {console2} from "@std/console2.sol";
import {Diamond} from "@diamond/Diamond.sol";

// solhint-disable no-console
contract DeployGovernorCoreFacet is Script {
    function run() external {
        vm.startBroadcast();

        GovernorCoreFacet governorCoreFacet = new GovernorCoreFacet();
        console2.log("GovernorCoreFacet deployed at", address(governorCoreFacet));

        vm.stopBroadcast();
    }
}

contract DeployGovernorSettingsFacet is Script {
    function run() external {
        vm.startBroadcast();

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        console2.log("GovernorSettingsFacet deployed at", address(governorSettingsFacet));

        vm.stopBroadcast();
    }
}

contract DeployGovernorFacets is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console2.log("DiamondCutFacet deployed at", address(diamondCutFacet));

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        console2.log("DiamondLoupeFacet deployed at", address(diamondLoupeFacet));

        OwnershipFacet ownershipFacet = new OwnershipFacet();
        console2.log("OwnershipFacet deployed at", address(ownershipFacet));

        GovernorCoreFacet governorCoreFacet = new GovernorCoreFacet();
        console2.log("GovernorCoreFacet deployed at", address(governorCoreFacet));

        GovernorSettingsFacet governorSettingsFacet = new GovernorSettingsFacet();
        console2.log("GovernorSettingsFacet deployed at", address(governorSettingsFacet));

        GovernorTimelockControlFacet governorTimelockControlFacet = new GovernorTimelockControlFacet();
        console2.log("GovernorTimelockControlFacet deployed at", address(governorTimelockControlFacet));

        vm.stopBroadcast();
    }
}

contract DeployGovernorDiamondInit is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        GovernorDiamondInit diamondInit = new GovernorDiamondInit();
        console2.log("GovernorDiamondInit deployed at:", address(diamondInit));
        vm.stopBroadcast();
    }
}

contract DeployGovernorDiamond is Script {
    function run(address admin, address diamondCutFacet) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        Diamond governor = new Diamond(admin, diamondCutFacet);
        console2.log("GovernorDiamond deployed at:", address(governor));
        vm.stopBroadcast();
    }
}

contract DeployGovernorTimelockController is Script {
    function run(address governor, uint256 timelockDelay) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address[] memory operators = new address[](1);
        operators[0] = governor;

        vm.startBroadcast(deployerPrivateKey);
        OrigamiTimelockController timelock = new OrigamiTimelockController(timelockDelay, operators, operators);
        console2.log("TimelockController deployed at:", address(timelock));
        vm.stopBroadcast();
    }
}

contract GovernorInstance is Script {
    struct GovernorConfig {
        string name;
        address diamondLoupeFacet;
        address ownershipFacet;
        address governorCoreFacet;
        address governorSettingsFacet;
        address governorTimelockControlFacet;
        address membershipToken;
        address governanceToken;
        address proposalToken;
        address proposalThresholdToken;
        uint256 proposalThreshold;
        uint64 votingPeriod;
        uint64 votingDelay;
        uint128 quorumPercentage;
    }

    function parseGovernorConfig(string calldata relativePath) public returns (GovernorConfig memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/", relativePath);
        string memory json = vm.readFile(path);
        GovernorConfig memory config = abi.decode(vm.parseJson(json), (GovernorConfig));
        // for some reason, this value isn't parsed correctly, so we give it an explicitly coerced value
        config.proposalThreshold = vm.parseJsonUint(json, ".k_proposalThreshold");
        return config;
    }

    function facetCuts(GovernorConfig memory config) public pure returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);

        cuts[0] = DiamondDeployHelper.diamondLoupeFacetCut(config.diamondLoupeFacet);
        cuts[1] = DiamondDeployHelper.ownershipFacetCut(config.ownershipFacet);
        cuts[2] = DiamondDeployHelper.governorCoreFacetCut(GovernorCoreFacet(config.governorCoreFacet));
        cuts[3] = DiamondDeployHelper.governorSettingsFacetCut(GovernorSettingsFacet(config.governorSettingsFacet));
        cuts[4] = DiamondDeployHelper.governorTimelockControlFacetCut(
            GovernorTimelockControlFacet(config.governorTimelockControlFacet)
        );

        return cuts;
    }

    function encodeConfig(address admin, address timelock, GovernorConfig memory config)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "init(string,address,address,address,address,address,uint64,uint64,uint128,uint256)",
            config.name,
            admin,
            timelock,
            config.membershipToken,
            config.proposalToken,
            config.proposalThresholdToken,
            config.votingDelay,
            config.votingPeriod,
            config.quorumPercentage,
            config.proposalThreshold
        );
    }

    function configure(
        address governorDiamondInit,
        address governorDiamond,
        address timelock,
        string calldata relativeConfigPath
    ) external {
        uint256 adminPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(adminPrivateKey);

        GovernorConfig memory config = parseGovernorConfig(relativeConfigPath);

        vm.startBroadcast(adminPrivateKey);
        IDiamondCut.FacetCut[] memory cuts = facetCuts(config);
        DiamondCutFacet(governorDiamond).diamondCut(cuts, governorDiamondInit, encodeConfig(admin, timelock, config));
        vm.stopBroadcast();
    }
}

/**
 * @dev this upgrades the diamond from a GovernorCoreFacet on `bf9c4b8` to one
 * on `710a92a` and the substantive change is to add the `getAccountNonce` fn
 */
contract UpgradeDiamondFromV001ToV002 is Script {
    function run(address governorDiamond, address newCoreFacet) external {
        bytes4[] memory replaces = new bytes4[](32);
        replaces[0] = 0xb08e51c0;
        replaces[1] = 0xa217fddf;
        replaces[2] = 0x253d2c7d;
        replaces[3] = 0xb03e27fc;
        replaces[4] = 0xa4785152;
        replaces[5] = 0x56781388;
        replaces[6] = 0xd17ad2d4;
        replaces[7] = 0x7b3c71d3;
        replaces[8] = 0xcd8514f6;
        replaces[9] = 0x78e890ba;
        replaces[10] = 0x248a9ca3;
        replaces[11] = 0x4b187e34;
        replaces[12] = 0x2f2ff15d;
        replaces[13] = 0x91d14854;
        replaces[14] = 0x43859632;
        replaces[15] = 0xc59057e4;
        replaces[16] = 0x06fdde03;
        replaces[17] = 0xc01f9e37;
        replaces[18] = 0x2d63f693;
        replaces[19] = 0x544ffc9c;
        replaces[20] = 0x7d5e81e2;
        replaces[21] = 0x362697b7;
        replaces[22] = 0xe5294480;
        replaces[23] = 0x443e5a58;
        replaces[24] = 0x6ce43248;
        replaces[25] = 0x8a8c79cf;
        replaces[26] = 0xf8ce560a;
        replaces[27] = 0x36568abe;
        replaces[28] = 0xd547741f;
        replaces[29] = 0x6c4b0e9f;
        replaces[30] = 0x3e4f49e6;
        replaces[31] = 0x54fd4d50;

        bytes4[] memory adds = new bytes4[](1);
        adds[0] = 0xd126199f;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: newCoreFacet,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: replaces
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: newCoreFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adds
        });

        vm.startBroadcast();
        DiamondCutFacet(governorDiamond).diamondCut(cuts, address(0), "");
        vm.stopBroadcast();
    }
}
