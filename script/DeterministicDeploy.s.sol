// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "src/OrigamiGovernanceToken.sol";
import "src/OrigamiMembershipToken.sol";
import "src/token/governance/ERC20Base.sol";
import "src/utils/L2StandardERC20.sol";

import "@std/Script.sol";
import "@oz/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@create3/CREATE3Factory.sol";

contract DeterministicDeploy is Script {
    function transparentProxyByteCode(address implementation, address proxyAdmin) public pure returns (bytes memory) {
        bytes memory contractBytecode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory encodedInitialization = abi.encode(implementation, proxyAdmin, "");
        return abi.encodePacked(contractBytecode, encodedInitialization);
    }

    function getDeterministicAddress(address create3Factory, address deployer, string calldata salt)
        public
        view
        returns (address)
    {
        return CREATE3Factory(create3Factory).getDeployed(deployer, bytes32(bytes(salt)));
    }

    function deployCreate3Factory() public {
        vm.startBroadcast();
        CREATE3Factory c3 = new CREATE3Factory();
        console2.log("CREATE3Factory deployed at", address(c3));
        vm.stopBroadcast();
    }

    function deployGovernanceTokenProxy(
        address create3Factory,
        string calldata orgSnowflake,
        address implementation,
        address proxyAdmin,
        address contractAdmin,
        string calldata name,
        string calldata symbol,
        uint256 supplyCap
    ) public {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = transparentProxyByteCode(implementation, proxyAdmin);
        string memory salt = string.concat("governance-token-", orgSnowflake);

        vm.startBroadcast();
        address govTokenProxy = c3.deploy(bytes32(bytes(salt)), bytecode);
        OrigamiGovernanceToken token = OrigamiGovernanceToken(govTokenProxy);
        token.initialize(contractAdmin, name, symbol, supplyCap);
        vm.stopBroadcast();
    }

    function configureGovernanceTokenProxyForL2(address govTokenProxy, address l2Bridge, address contractAdmin)
        public
    {
        vm.startBroadcast();
        L2StandardERC20 token = L2StandardERC20(govTokenProxy);
        token.setL1Token(govTokenProxy); // relies on CREATE3Factory to deploy to same address on L1 and L2
        token.setL2Bridge(l2Bridge);

        OrigamiGovernanceToken govToken = OrigamiGovernanceToken(govTokenProxy);
        govToken.enableTransfer();
        govToken.enableBurn();
        govToken.revokeRole(govToken.MINTER_ROLE(), contractAdmin);
        govToken.grantRole(govToken.MINTER_ROLE(), l2Bridge);
        govToken.grantRole(govToken.BURNER_ROLE(), l2Bridge);
        vm.stopBroadcast();
    }

    function configureGovernanceTokenProxyForL1(address govTokenProxy) public {
        vm.startBroadcast();
        OrigamiGovernanceToken govToken = OrigamiGovernanceToken(govTokenProxy);
        govToken.enableTransfer();
        govToken.enableBurn();
        vm.stopBroadcast();
    }

    function deployMembershipTokenProxy(
        address create3Factory,
        string calldata orgSnowflake,
        address implementation,
        address proxyAdmin,
        address contractAdmin,
        string calldata name,
        string calldata symbol,
        string calldata baseUri
    ) public {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = transparentProxyByteCode(implementation, proxyAdmin);
        string memory salt = string.concat("membership-token-", orgSnowflake);

        vm.startBroadcast();
        address memTokenProxy = c3.deploy(bytes32(bytes(salt)), bytecode);
        OrigamiMembershipToken token = OrigamiMembershipToken(memTokenProxy);
        token.initialize(contractAdmin, name, symbol, baseUri);
        vm.stopBroadcast();
    }

    function deployERC20BaseImpl(address create3Factory, string memory salt) public {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = type(ERC20Base).creationCode;
        salt = string.concat("erc20-base-", salt);

        vm.startBroadcast();
        address erc20Base = c3.deploy(bytes32(bytes(salt)), bytecode);
        console2.log("ERC20Base deployed at", erc20Base);
        vm.stopBroadcast();
    }

    function deployGovernanceTokenImpl(address create3Factory, string memory salt) public {
        CREATE3Factory c3 = CREATE3Factory(create3Factory);
        bytes memory bytecode = type(OrigamiGovernanceToken).creationCode;
        salt = string.concat("gov-token-", salt);

        vm.startBroadcast();
        address govToken = c3.deploy(bytes32(bytes(salt)), bytecode);
        console2.log("OrigamiGovernanceToken deployed at", govToken);
        vm.stopBroadcast();
    }
}
