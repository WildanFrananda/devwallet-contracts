// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Phase 0 stub. Real claim/cooldown/rate-limit logic lands in Phase 1.
contract FaucetDispenser {
    address public owner;
    uint256 public dripAmount;

    event Claimed(address indexed recipient, uint256 amount);

    error NotOwner();
    error ZeroRecipient();

    constructor(uint256 _dripAmount) payable {
        owner = msg.sender;
        dripAmount = _dripAmount;
    }

    function claim(address recipient) external {
        if (recipient == address(0)) revert ZeroRecipient();
        emit Claimed(recipient, dripAmount);
    }

    function setDripAmount(uint256 newAmount) external {
        if (msg.sender != owner) revert NotOwner();
        dripAmount = newAmount;
    }
}
