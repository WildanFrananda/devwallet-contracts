// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FaucetDispenser} from "../src/FaucetDispenser.sol";

contract FaucetDispenserTest is Test {
    FaucetDispenser dispenser;
    address constant USER = address(0xBEEF);
    address constant SECOND_USER = address(0xCAFE);
    address constant NON_OWNER = address(0xDEAD);

    uint256 constant DRIP = 0.05 ether;
    uint256 constant COOLDOWN = 24 hours;
    uint256 constant FUND = 1 ether;

    function setUp() public {
        dispenser = new FaucetDispenser{value: FUND}(DRIP, COOLDOWN);
    }

    function test_InitialState() public view {
        assertEq(dispenser.dripAmount(), DRIP);
        assertEq(dispenser.cooldown(), COOLDOWN);
        assertEq(dispenser.owner(), address(this));
        assertEq(address(dispenser).balance, FUND);
    }

    function test_DripTransfersFundsAndEmitsEvent() public {
        uint256 balanceBefore = USER.balance;
        vm.expectEmit(true, false, false, true);
        emit FaucetDispenser.Dripped(USER, DRIP, block.timestamp + COOLDOWN);
        dispenser.drip(USER);
        assertEq(USER.balance, balanceBefore + DRIP);
        assertEq(dispenser.lastDripAt(USER), block.timestamp);
    }

    function test_DripRevertsOnZeroRecipient() public {
        vm.expectRevert(FaucetDispenser.ZeroRecipient.selector);
        dispenser.drip(address(0));
    }

    function test_DripRevertsForNonOwner() public {
        vm.prank(NON_OWNER);
        vm.expectRevert(FaucetDispenser.NotOwner.selector);
        dispenser.drip(USER);
    }

    function test_DripEnforcesCooldown() public {
        dispenser.drip(USER);
        uint256 expectedNext = block.timestamp + COOLDOWN;
        vm.expectRevert(abi.encodeWithSelector(FaucetDispenser.CooldownActive.selector, expectedNext));
        dispenser.drip(USER);
    }

    function test_DripAllowsAfterCooldown() public {
        dispenser.drip(USER);
        skip(COOLDOWN);
        dispenser.drip(USER);
        assertEq(USER.balance, DRIP * 2);
    }

    function test_DripCooldownIsPerRecipient() public {
        dispenser.drip(USER);
        dispenser.drip(SECOND_USER);
        assertEq(SECOND_USER.balance, DRIP);
    }

    function test_DripRevertsWhenFaucetEmpty() public {
        dispenser.setCooldown(0);
        uint256 dripsAvailable = FUND / DRIP;
        for (uint256 i = 0; i < dripsAvailable; i++) {
            dispenser.drip(address(uint160(0x1000 + i)));
        }
        assertEq(address(dispenser).balance, 0);
        vm.expectRevert(abi.encodeWithSelector(FaucetDispenser.FaucetEmpty.selector, 0, DRIP));
        dispenser.drip(USER);
    }

    function test_NextDripAtReturnsZeroForUnclaimed() public view {
        assertEq(dispenser.nextDripAt(USER), 0);
    }

    function test_NextDripAtAfterClaim() public {
        dispenser.drip(USER);
        assertEq(dispenser.nextDripAt(USER), block.timestamp + COOLDOWN);
    }

    function test_SetDripAmountByOwner() public {
        vm.expectEmit(false, false, false, true);
        emit FaucetDispenser.DripAmountUpdated(DRIP, 0.1 ether);
        dispenser.setDripAmount(0.1 ether);
        assertEq(dispenser.dripAmount(), 0.1 ether);
    }

    function test_SetDripAmountRevertsForNonOwner() public {
        vm.prank(NON_OWNER);
        vm.expectRevert(FaucetDispenser.NotOwner.selector);
        dispenser.setDripAmount(0.1 ether);
    }

    function test_SetCooldownByOwner() public {
        vm.expectEmit(false, false, false, true);
        emit FaucetDispenser.CooldownUpdated(COOLDOWN, 1 hours);
        dispenser.setCooldown(1 hours);
        assertEq(dispenser.cooldown(), 1 hours);
    }

    function test_SetCooldownRevertsForNonOwner() public {
        vm.prank(NON_OWNER);
        vm.expectRevert(FaucetDispenser.NotOwner.selector);
        dispenser.setCooldown(1 hours);
    }

    function test_TransferOwnership() public {
        address newOwner = address(0x1234);
        vm.expectEmit(true, true, false, false);
        emit FaucetDispenser.OwnerTransferred(address(this), newOwner);
        dispenser.transferOwnership(newOwner);
        assertEq(dispenser.owner(), newOwner);
        vm.expectRevert(FaucetDispenser.NotOwner.selector);
        dispenser.drip(USER);
        vm.prank(newOwner);
        dispenser.drip(USER);
    }

    function test_TransferOwnershipRevertsForZeroAddress() public {
        vm.expectRevert(FaucetDispenser.ZeroNewOwner.selector);
        dispenser.transferOwnership(address(0));
    }

    function test_TransferOwnershipRevertsForNonOwner() public {
        vm.prank(NON_OWNER);
        vm.expectRevert(FaucetDispenser.NotOwner.selector);
        dispenser.transferOwnership(NON_OWNER);
    }

    function test_ReceiveEmitsFundedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit FaucetDispenser.Funded(address(this), 0.5 ether);
        (bool ok, ) = address(dispenser).call{value: 0.5 ether}("");
        assertTrue(ok);
        assertEq(address(dispenser).balance, FUND + 0.5 ether);
    }

    function testFuzz_DripCooldownNeverShrinks(uint64 elapsed) public {
        vm.assume(elapsed < COOLDOWN);
        dispenser.drip(USER);
        skip(elapsed);
        vm.expectRevert();
        dispenser.drip(USER);
    }
}
