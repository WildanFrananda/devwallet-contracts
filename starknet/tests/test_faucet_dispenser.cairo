use starknet::ContractAddress;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
    start_cheat_caller_address_global, stop_cheat_caller_address_global,
};
use devwallet_faucet::faucet_dispenser::{IFaucetDispenserDispatcher, IFaucetDispenserDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

const OWNER_RAW: felt252 = 0x111;
const RECIPIENT_RAW: felt252 = 0xBEEF;
const SECOND_USER_RAW: felt252 = 0xCAFE;
const NON_OWNER_RAW: felt252 = 0xDEAD;

const DRIP_AMOUNT_LOW: u128 = 1000;
const COOLDOWN: u64 = 86400;
const TOKEN_SUPPLY_LOW: u128 = 1_000_000;

fn owner() -> ContractAddress {
    OWNER_RAW.try_into().unwrap()
}

fn recipient() -> ContractAddress {
    RECIPIENT_RAW.try_into().unwrap()
}

fn second_user() -> ContractAddress {
    SECOND_USER_RAW.try_into().unwrap()
}

fn non_owner() -> ContractAddress {
    NON_OWNER_RAW.try_into().unwrap()
}

fn drip_amount_u256() -> u256 {
    u256 { low: DRIP_AMOUNT_LOW, high: 0 }
}

fn deploy_strk() -> ContractAddress {
    let contract = declare("MockStrk").unwrap().contract_class();
    let supply = u256 { low: TOKEN_SUPPLY_LOW, high: 0 };
    let mut calldata: Array<felt252> = ArrayTrait::new();
    let owner_addr = owner();
    owner_addr.serialize(ref calldata);
    supply.serialize(ref calldata);
    let (token_address, _) = contract.deploy(@calldata).unwrap();
    token_address
}

fn deploy_faucet(strk: ContractAddress) -> ContractAddress {
    let contract = declare("FaucetDispenser").unwrap().contract_class();
    let mut calldata: Array<felt252> = ArrayTrait::new();
    let owner_addr = owner();
    owner_addr.serialize(ref calldata);
    strk.serialize(ref calldata);
    drip_amount_u256().serialize(ref calldata);
    COOLDOWN.serialize(ref calldata);
    let (faucet_address, _) = contract.deploy(@calldata).unwrap();
    faucet_address
}

fn fund_faucet(strk: ContractAddress, faucet: ContractAddress, amount: u256) {
    let token = IERC20Dispatcher { contract_address: strk };
    start_cheat_caller_address_global(owner());
    let ok = token.transfer(faucet, amount);
    assert(ok, 'fund transfer failed');
    stop_cheat_caller_address_global();
}

fn setup() -> (IFaucetDispenserDispatcher, IERC20Dispatcher, ContractAddress) {
    let strk = deploy_strk();
    let faucet = deploy_faucet(strk);
    fund_faucet(strk, faucet, u256 { low: 10_000, high: 0 });
    (
        IFaucetDispenserDispatcher { contract_address: faucet },
        IERC20Dispatcher { contract_address: strk },
        faucet,
    )
}

#[test]
fn test_initial_state() {
    let (faucet, _, _) = setup();
    assert(faucet.owner() == owner(), 'owner mismatch');
    assert(faucet.drip_amount() == drip_amount_u256(), 'drip amount mismatch');
    assert(faucet.cooldown() == COOLDOWN, 'cooldown mismatch');
    assert(faucet.next_drip_at(recipient()) == 0, 'unclaimed should be 0');
}

#[test]
fn test_drip_transfers_funds_and_records_timestamp() {
    let (faucet, token, _) = setup();
    let now: u64 = 1000;
    start_cheat_block_timestamp_global(now);
    start_cheat_caller_address_global(owner());
    faucet.drip(recipient());
    stop_cheat_caller_address_global();

    let balance = token.balance_of(recipient());
    assert(balance == drip_amount_u256(), 'recipient balance mismatch');
    assert(faucet.next_drip_at(recipient()) == now + COOLDOWN, 'next_drip_at mismatch');
}

#[test]
#[should_panic(expected: 'ZeroRecipient')]
fn test_drip_rejects_zero_recipient() {
    let (faucet, _, _) = setup();
    start_cheat_caller_address_global(owner());
    let zero: ContractAddress = 0.try_into().unwrap();
    faucet.drip(zero);
    stop_cheat_caller_address_global();
}

#[test]
#[should_panic(expected: 'NotOwner')]
fn test_drip_rejects_non_owner() {
    let (faucet, _, _) = setup();
    start_cheat_caller_address_global(non_owner());
    faucet.drip(recipient());
    stop_cheat_caller_address_global();
}

#[test]
#[should_panic(expected: 'CooldownActive')]
fn test_drip_enforces_cooldown_per_recipient() {
    let (faucet, _, _) = setup();
    start_cheat_block_timestamp_global(1000);
    start_cheat_caller_address_global(owner());
    faucet.drip(recipient());
    faucet.drip(recipient());
    stop_cheat_caller_address_global();
}

#[test]
fn test_drip_allows_second_recipient_immediately() {
    let (faucet, token, _) = setup();
    start_cheat_block_timestamp_global(1000);
    start_cheat_caller_address_global(owner());
    faucet.drip(recipient());
    faucet.drip(second_user());
    stop_cheat_caller_address_global();
    assert(token.balance_of(second_user()) == drip_amount_u256(), 'second user balance');
}

#[test]
fn test_drip_succeeds_after_cooldown() {
    let (faucet, token, _) = setup();
    start_cheat_caller_address_global(owner());
    start_cheat_block_timestamp_global(1000);
    faucet.drip(recipient());
    start_cheat_block_timestamp_global(1000 + COOLDOWN);
    faucet.drip(recipient());
    stop_cheat_caller_address_global();
    let expected = drip_amount_u256() + drip_amount_u256();
    assert(token.balance_of(recipient()) == expected, 'second drip mismatch');
}

#[test]
fn test_set_drip_amount_by_owner() {
    let (faucet, _, _) = setup();
    let new_amount = u256 { low: 5000, high: 0 };
    start_cheat_caller_address_global(owner());
    faucet.set_drip_amount(new_amount);
    stop_cheat_caller_address_global();
    assert(faucet.drip_amount() == new_amount, 'drip amount not updated');
}

#[test]
#[should_panic(expected: 'NotOwner')]
fn test_set_drip_amount_rejects_non_owner() {
    let (faucet, _, _) = setup();
    let new_amount = u256 { low: 5000, high: 0 };
    start_cheat_caller_address_global(non_owner());
    faucet.set_drip_amount(new_amount);
    stop_cheat_caller_address_global();
}

#[test]
fn test_transfer_ownership() {
    let (faucet, _, _) = setup();
    let new_owner: ContractAddress = 0x1234.try_into().unwrap();
    start_cheat_caller_address_global(owner());
    faucet.transfer_ownership(new_owner);
    stop_cheat_caller_address_global();
    assert(faucet.owner() == new_owner, 'owner not transferred');
}

#[test]
#[should_panic(expected: 'ZeroNewOwner')]
fn test_transfer_ownership_rejects_zero() {
    let (faucet, _, _) = setup();
    let zero: ContractAddress = 0.try_into().unwrap();
    start_cheat_caller_address_global(owner());
    faucet.transfer_ownership(zero);
    stop_cheat_caller_address_global();
}
