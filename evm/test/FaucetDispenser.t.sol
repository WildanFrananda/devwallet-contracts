// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FaucetDispenser} from "../src/FaucetDispenser.sol";

contract FaucetDispenserTest is Test {
    FaucetDispenser dispenser;

    function setUp() public {
        dispenser = new FaucetDispenser(0.05 ether);
    }

    function test_InitialState() public view {
        assertEq(dispenser.dripAmount(), 0.05 ether);
        assertEq(dispenser.owner(), address(this));
    }

    function test_ClaimEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit FaucetDispenser.Claimed(address(0xBEEF), 0.05 ether);
        dispenser.claim(address(0xBEEF));
    }

    function test_ClaimRevertsOnZeroRecipient() public {
        vm.expectRevert(FaucetDispenser.ZeroRecipient.selector);
        dispenser.claim(address(0));
    }

    function test_SetDripAmountByOwner() public {
        dispenser.setDripAmount(0.1 ether);
        assertEq(dispenser.dripAmount(), 0.1 ether);
    }

    function test_SetDripAmountRevertsForNonOwner() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(FaucetDispenser.NotOwner.selector);
        dispenser.setDripAmount(0.1 ether);
    }
}
