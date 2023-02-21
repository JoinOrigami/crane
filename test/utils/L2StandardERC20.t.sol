// SPDX-License-Identifier: ITSATEST
pragma solidity 0.8.16;

import "src/utils/L2StandardERC20.sol";

import "src/interfaces/utils/IL2StandardERC20.sol";
import "@oz/proxy/transparent/ProxyAdmin.sol";
import "@std/Test.sol";

abstract contract L2StandardERC20Helper {
    address public deployer = address(0x1);
    address public owner = address(0x2);

    address public token = address(0x3);
    address public bridge = address(0x4);
}

contract L2ChildContractHelper is L2StandardERC20Helper, Test {
    L2StandardERC20 public impl;
    ProxyAdmin public proxyAdmin;
    L2StandardERC20 public child;

    constructor() {
        vm.startPrank(deployer);
        impl = new L2StandardERC20();
        proxyAdmin = new ProxyAdmin();

        TransparentUpgradeableProxy proxy;
        proxy = new TransparentUpgradeableProxy(address(impl), address(proxyAdmin), "");
        child = L2StandardERC20(address(proxy));
        child.initialize(owner, "Test", "TST", 1000);
        vm.stopPrank();
        vm.startPrank(owner);
        child.setL1Token(token);
        child.setL2Bridge(bridge);
        vm.stopPrank();
    }
}

contract TestL2ChildContract is L2ChildContractHelper {
    event Mint(address indexed _account, uint256 _amount);
    event Burn(address indexed _account, uint256 _amount);
    event L1TokenUpdated(address indexed oldL1Token, address indexed newL1Token);
    event L2BridgeUpdated(address indexed oldL2Bridge, address indexed newL2Bridge);

    function testL1Token() public {
        assertEq(child.l1Token(), token);
    }

    function testL2Bridge() public {
        assertEq(child.l2Bridge(), bridge);
    }

    function testSetL1Token() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(child));
        emit L1TokenUpdated(address(0x3), address(0x5));
        child.setL1Token(address(0x5));
        assertEq(child.l1Token(), address(0x5));
    }

    function testSetL2Bridge() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(child));
        emit L2BridgeUpdated(address(0x4), address(0x6));
        child.setL2Bridge(address(0x6));
        assertEq(child.l2Bridge(), address(0x6));
    }

    function testMint() public {
        vm.prank(bridge);
        vm.expectEmit(true, true, true, true, address(child));
        emit Mint(owner, 100);
        child.mint(owner, 100);
    }

    function testBurn() public {
        vm.startPrank(bridge);
        child.mint(owner, 100);
        vm.expectEmit(true, true, true, true, address(child));
        emit Burn(owner, 100);
        child.burn(owner, 100);
    }

    function testNonBridgeMint() public {
        vm.prank(owner);
        vm.expectRevert("L2StandardERC20: only L2 Bridge can mint and burn");
        child.mint(owner, 100);
    }

    function testNonBridgeBurn() public {
        vm.prank(bridge);
        child.mint(owner, 100);
        vm.prank(owner);
        vm.expectRevert("L2StandardERC20: only L2 Bridge can mint and burn");
        child.burn(owner, 100);
    }

    function testSupportsIL2StandardERC20() public {
        assertTrue(child.supportsInterface(type(IL2StandardERC20).interfaceId));
        assertTrue(child.supportsInterface(type(IERC165).interfaceId));
        assertTrue(child.supportsInterface(type(ILegacyMintableERC20).interfaceId));
        // assert the bytes4 values of the interface ids since the bridge depends on them
        assertEq(child.supportsInterface(0x01ffc9a7), true); // IERC165
        assertEq(child.supportsInterface(0x1d1d8b63), true); // ILegacyMintableERC20
    }

    function testOnlyAdminCanSetL1Token() public {
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        child.setL1Token(address(0x5));
    }

    function testOnlyAdminCanSetL2Bridge() public {
        vm.expectRevert(
            "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        child.setL2Bridge(address(0x6));
    }
}
