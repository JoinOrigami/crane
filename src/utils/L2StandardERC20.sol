// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/interfaces/utils/IL2StandardERC20.sol";
import "@diamond/interfaces/IERC165.sol";
import "@oz-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * @title L2StandardERC20
 * @notice an ERC20 extension that is compatible with the Optimism bridge
 */
abstract contract L2StandardERC20 is IL2StandardERC20, ERC20Upgradeable {
    bytes32 public constant L2BRIDGE_INFO_STORAGE_POSITION = keccak256("com.origami.l2bridge.info");

    /// @dev diamond storage for L2BridgeInfo so it's upgrade-compatible
    struct L2BridgeInfo {
        address l1Token;
        address l2Bridge;
    }

    /// @dev returns the storage pointer for the L2BridgeInfo struct
    function l2BridgeInfoStorage() internal pure returns (L2BridgeInfo storage l2bi) {
        bytes32 position = L2BRIDGE_INFO_STORAGE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            l2bi.slot := position
        }
    }

    /**
     * @notice returns the address of the paired ERC20 token on L1
     * @dev this is part of the ILegacyMintableERC20 interface
     */
    function l1Token() public view returns (address) {
        return l2BridgeInfoStorage().l1Token;
    }

    /**
     * @notice returns the address of the bridge contract on L2
     * @dev this is _not_ part of the ILegacyMintableERC20 interface, but is still required for compatibility
     */
    function l2Bridge() public view returns (address) {
        return l2BridgeInfoStorage().l2Bridge;
    }

    /**
     * @notice sets the address of the paired ERC20 token on L1
     * @param _l1Token address of the paired ERC20 token on L1
     */
    function setL1Token(address _l1Token) public {
        l2BridgeInfoStorage().l1Token = _l1Token;
    }

    /**
     * @notice sets the address of the bridge contract on L2
     * @param _l2Bridge address of the bridge contract on L2
     */
    function setL2Bridge(address _l2Bridge) public {
        l2BridgeInfoStorage().l2Bridge = _l2Bridge;
    }

    /**
     * @notice returns true if the contract implements the interface defined by interfaceId
     * @param interfaceId bytes4 of the interface
     * @dev the IERC165 and ILegacyMintableERC20interfaces interfaces are critical for compatiblity with the OP bridge
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(ILegacyMintableERC20).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IL2StandardERC20).interfaceId;
    }

    /**
     * @notice mints tokens on L2
     * @param account address to mint tokens to
     * @param amount amount of tokens to mint
     * @dev overriden so we can emit Mint, which is part of the IL2StandardERC20 interface
     */
    function mint(address account, uint256 amount) public virtual override onlyL2Bridge {
        super._mint(account, amount);
        emit Mint(account, amount);
    }

    /**
     * @notice burns tokens on L2
     * @param account address to burn tokens from
     * @param amount amount of tokens to burn
     * @dev overriden so we can emit Burn, which is part of the IL2StandardERC20 interface
     */
    function burn(address account, uint256 amount) public virtual override onlyL2Bridge {
        super._burn(account, amount);
        emit Burn(account, amount);
    }

    /// @dev modifier to restrict minting and burning rights to only the L2 bridge
    modifier onlyL2Bridge() {
        require(msg.sender == l2Bridge(), "L2StandardERC20: only L2 Bridge can mint and burn");
        _;
    }
}