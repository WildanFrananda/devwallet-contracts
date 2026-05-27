// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FaucetDispenser
 * @notice Owner-gated testnet faucet. The DevWallet backend acts as the
 *         single authorized caller and dispenses native testnet currency to
 *         end-users on a per-recipient cooldown.
 *
 * Threat model:
 *   - This is testnet-only. No real value is at stake.
 *   - The sponsor (owner) key lives in the backend `.env` and signs every
 *     `drip` call. If compromised, an attacker can drain the contract and
 *     halt service — but not steal user funds (users never trust this
 *     contract custodially).
 *   - On-chain cooldown defends against the sponsor accidentally
 *     double-dipping a user inside the cooldown window.
 */
contract FaucetDispenser {
    address public owner;
    uint256 public dripAmount;
    uint256 public cooldown;
    mapping(address => uint256) public lastDripAt;

    event Dripped(address indexed recipient, uint256 amount, uint256 nextAvailableAt);
    event DripAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event CooldownUpdated(uint256 oldCooldown, uint256 newCooldown);
    event OwnerTransferred(address indexed previousOwner, address indexed newOwner);
    event Funded(address indexed from, uint256 amount);

    error NotOwner();
    error ZeroRecipient();
    error ZeroNewOwner();
    error CooldownActive(uint256 nextAvailableAt);
    error FaucetEmpty(uint256 balance, uint256 required);
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint256 _dripAmount, uint256 _cooldown) payable {
        owner = msg.sender;
        dripAmount = _dripAmount;
        cooldown = _cooldown;
        if (msg.value > 0) emit Funded(msg.sender, msg.value);
    }

    /// @notice Dispense `dripAmount` to `recipient`. Reverts if the recipient
    ///         is still within the cooldown window or the contract balance
    ///         is insufficient.
    function drip(address recipient) external onlyOwner {
        if (recipient == address(0)) revert ZeroRecipient();
        uint256 last = lastDripAt[recipient];
        if (last != 0) {
            uint256 nextAvailable = last + cooldown;
            if (block.timestamp < nextAvailable) revert CooldownActive(nextAvailable);
        }
        if (address(this).balance < dripAmount) revert FaucetEmpty(address(this).balance, dripAmount);

        lastDripAt[recipient] = block.timestamp;
        emit Dripped(recipient, dripAmount, block.timestamp + cooldown);
        (bool ok, ) = recipient.call{value: dripAmount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Returns the timestamp when `recipient` becomes eligible again.
    function nextDripAt(address recipient) external view returns (uint256) {
        uint256 last = lastDripAt[recipient];
        if (last == 0) return 0;
        return last + cooldown;
    }

    function setDripAmount(uint256 newAmount) external onlyOwner {
        emit DripAmountUpdated(dripAmount, newAmount);
        dripAmount = newAmount;
    }

    function setCooldown(uint256 newCooldown) external onlyOwner {
        emit CooldownUpdated(cooldown, newCooldown);
        cooldown = newCooldown;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroNewOwner();
        emit OwnerTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Accept native testnet currency to refill the faucet.
    receive() external payable {
        emit Funded(msg.sender, msg.value);
    }
}
