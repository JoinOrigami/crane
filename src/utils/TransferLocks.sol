// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "src/interfaces/ITransferLocks.sol";
import "src/token/governance/ERC20Base.sol";
import "src/utils/TransferLocksStorage.sol";
import "@diamond/interfaces/IERC165.sol";

/**
 * @title TransferLocks
 * @author Origami
 * @notice this library enables time-locked transfers of ERC20 tokens.
 * Transferlocks are the inverse of a vesting schedule. They allow the holder to
 * vote with their weight but not to tranfer them before a certain date.
 * @dev TransferLocks are resilient to timestamp manipulation by using
 * block.timestamp, locks will typically be measured in months, not seconds.
 * @custom:security-contact contract-security@joinorigami.com
 */
abstract contract TransferLocks is ERC20Base, IERC165, ITransferLocks {
    /// @inheritdoc ITransferLocks
    function addTransferLock(uint256 amount, uint256 deadline) public whenValidLock(amount, deadline) {
        TransferLocksStorage.addTransferLock(msg.sender, amount, deadline);
    }

    /// @inheritdoc ITransferLocks
    function getTransferLockTotal(address account) public view returns (uint256 amount) {
        return TransferLocksStorage.getTotalLockedAt(account, block.timestamp);
    }

    /// @inheritdoc ITransferLocks
    function getTransferLockTotalAt(address account, uint256 timestamp) public view returns (uint256 amount) {
        return TransferLocksStorage.getTotalLockedAt(account, timestamp);
    }

    /// @inheritdoc ITransferLocks
    function getAvailableBalanceAt(address account, uint256 timestamp) public view returns (uint256 amount) {
        uint256 totalLocked = TransferLocksStorage.getTotalLockedAt(account, timestamp);
        return balanceOf(account) - totalLocked;
    }

    /// @dev Override ERC20Upgradeable._beforeTokenTransfer to check for transfer locks.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        uint256 lockedAmount = getTransferLockTotalAt(from, block.timestamp);
        // slither-disable-next-line timestamp
        if (lockedAmount > 0 && balanceOf(from) >= amount) {
            // slither-disable-next-line timestamp
            require(balanceOf(from) - amount >= lockedAmount, "TransferLock: this exceeds your unlocked balance");
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    /// @inheritdoc ITransferLocks
    function transferWithLock(address recipient, uint256 amount, uint256 deadline)
        public
        whenValidLock(amount, deadline)
    {
        _transfer(msg.sender, recipient, amount);
        TransferLocksStorage.addTransferLock(recipient, amount, deadline);
    }

    /// @inheritdoc ITransferLocks
    function batchTransferWithLocks(
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256[] calldata deadlines
    ) external {
        require(recipients.length == amounts.length, "TransferLock: recipients and amounts must be the same length");
        require(recipients.length == deadlines.length, "TransferLock: recipients and deadlines must be the same length");
        for (uint256 i = 0; i < recipients.length; i++) {
            transferWithLock(recipients[i], amounts[i], deadlines[i]);
        }
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC20Base, IERC165) returns (bool) {
        return interfaceId == type(ITransferLocks).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Modifier to check that the deadline is in the future and the amount is not greater than the available balance.
    modifier whenValidLock(uint256 amount, uint256 deadline) {
        // slither-disable-next-line timestamp
        require(deadline > block.timestamp, "TransferLock: deadline must be in the future");
        require(
            amount <= getAvailableBalanceAt(msg.sender, deadline),
            "TransferLock: amount cannot exceed available balance"
        );
        _;
    }
}
