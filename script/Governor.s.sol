// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@std/Script.sol";

import "src/OrigamiGovernorDiamond.sol";
import "src/OrigamiTimelockController.sol";
import "src/utils/DiamondDeployHelper.sol";
import "src/utils/GovernorDiamondInit.sol";

contract DeployGovernorFacets is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
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

contract DeployGovernorInstance is Script {
    struct GovernorConfig {
        string name;
        address diamondCutFacet;
        address diamondLoupeFacet;
        address ownershipFacet;
        address governorCoreFacet;
        address governorSettingsFacet;
        address governorTimelockControlFacet;
        address membershipToken;
        address proposalToken;
        address proposalThresholdToken;
        uint256 proposalThreshold;
        uint256 timelockDelay;
        uint256 votingPeriod;
        uint256 votingDelay;
        uint256 quorumPercentage;
    }

    function parseGovernorConfig(string calldata relativePath) public returns (GovernorConfig memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/", relativePath);
        string memory json = vm.readFile(path);
        return abi.decode(vm.parseJson(json), (GovernorConfig));
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

    function timelockController(uint256 delay, address operator) public returns (OrigamiTimelockController) {
        address[] memory operators = new address[](1);
        operators[0] = operator;
        return new OrigamiTimelockController(delay, operators, operators);
    }

    function encodeConfig(GovernorConfig memory config) public pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "init(string,address,address,address,address,address,uint64,uint64,uint128,uint256)",
            config.name,
            config.membershipToken,
            config.proposalToken,
            config.proposalThresholdToken,
            config.votingDelay,
            config.votingPeriod,
            config.quorumPercentage,
            config.proposalThreshold
        );
    }

    function run(string calldata relativeConfigPath) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 adminPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        address admin = vm.addr(adminPrivateKey);

        GovernorConfig memory config = parseGovernorConfig(relativeConfigPath);

        vm.startBroadcast(deployerPrivateKey);
        OrigamiGovernorDiamond governor = new OrigamiGovernorDiamond(admin, config.diamondCutFacet);
        IDiamondCut.FacetCut[] memory cuts = facetCuts(config);
        GovernorDiamondInit diamondInitializer = new GovernorDiamondInit();
        vm.stopBroadcast();

        vm.startBroadcast(adminPrivateKey);
        DiamondCutFacet(address(governor)).diamondCut(cuts, address(diamondInitializer), encodeConfig(config));
        vm.stopBroadcast();
    }
}
