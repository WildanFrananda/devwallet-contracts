use starknet::ContractAddress;

/// Owner-gated testnet STRK faucet, mirror of `evm/src/FaucetDispenser.sol`.
/// The DevWallet backend acts as the single authorized caller and the
/// contract dispenses STRK to recipients on a per-recipient cooldown.
#[starknet::interface]
pub trait IFaucetDispenser<TContractState> {
    /// Dispense `drip_amount` STRK to `recipient`. Reverts on `NotOwner`,
    /// `CooldownActive`, or `FaucetEmpty`.
    fn drip(ref self: TContractState, recipient: ContractAddress);

    /// View — UNIX timestamp when `recipient` becomes eligible again, or
    /// 0 if the recipient has never received a drip.
    fn next_drip_at(self: @TContractState, recipient: ContractAddress) -> u64;

    fn drip_amount(self: @TContractState) -> u256;
    fn cooldown(self: @TContractState) -> u64;
    fn owner(self: @TContractState) -> ContractAddress;
    fn strk_token(self: @TContractState) -> ContractAddress;

    fn set_drip_amount(ref self: TContractState, new_amount: u256);
    fn set_cooldown(ref self: TContractState, new_cooldown: u64);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}

#[starknet::contract]
pub mod FaucetDispenser {
    use core::num::traits::Zero;
    use starknet::ContractAddress;
    use starknet::{get_block_timestamp, get_caller_address, get_contract_address};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        strk_token: ContractAddress,
        drip_amount: u256,
        cooldown_seconds: u64,
        last_drip_at: Map<ContractAddress, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Dripped: Dripped,
        DripAmountUpdated: DripAmountUpdated,
        CooldownUpdated: CooldownUpdated,
        OwnerTransferred: OwnerTransferred,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Dripped {
        #[key]
        pub recipient: ContractAddress,
        pub amount: u256,
        pub next_available_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DripAmountUpdated {
        pub old_amount: u256,
        pub new_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CooldownUpdated {
        pub old_cooldown: u64,
        pub new_cooldown: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OwnerTransferred {
        #[key]
        pub previous_owner: ContractAddress,
        #[key]
        pub new_owner: ContractAddress,
    }

    pub mod Errors {
        pub const NOT_OWNER: felt252 = 'NotOwner';
        pub const ZERO_RECIPIENT: felt252 = 'ZeroRecipient';
        pub const ZERO_NEW_OWNER: felt252 = 'ZeroNewOwner';
        pub const COOLDOWN_ACTIVE: felt252 = 'CooldownActive';
        pub const FAUCET_EMPTY: felt252 = 'FaucetEmpty';
        pub const TRANSFER_FAILED: felt252 = 'TransferFailed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        strk_token: ContractAddress,
        drip_amount: u256,
        cooldown_seconds: u64,
    ) {
        self.owner.write(owner);
        self.strk_token.write(strk_token);
        self.drip_amount.write(drip_amount);
        self.cooldown_seconds.write(cooldown_seconds);
    }

    #[abi(embed_v0)]
    impl FaucetDispenserImpl of super::IFaucetDispenser<ContractState> {
        fn drip(ref self: ContractState, recipient: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), Errors::NOT_OWNER);
            assert(!recipient.is_zero(), Errors::ZERO_RECIPIENT);

            let now = get_block_timestamp();
            let cooldown = self.cooldown_seconds.read();
            let last = self.last_drip_at.read(recipient);
            if last != 0 {
                assert(now >= last + cooldown, Errors::COOLDOWN_ACTIVE);
            }

            let amount = self.drip_amount.read();
            let token = IERC20Dispatcher { contract_address: self.strk_token.read() };
            let balance = token.balance_of(get_contract_address());
            assert(balance >= amount, Errors::FAUCET_EMPTY);

            self.last_drip_at.write(recipient, now);
            let ok = token.transfer(recipient, amount);
            assert(ok, Errors::TRANSFER_FAILED);
            self.emit(Dripped { recipient, amount, next_available_at: now + cooldown });
        }

        fn next_drip_at(self: @ContractState, recipient: ContractAddress) -> u64 {
            let last = self.last_drip_at.read(recipient);
            if last == 0 {
                0
            } else {
                last + self.cooldown_seconds.read()
            }
        }

        fn drip_amount(self: @ContractState) -> u256 {
            self.drip_amount.read()
        }

        fn cooldown(self: @ContractState) -> u64 {
            self.cooldown_seconds.read()
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn strk_token(self: @ContractState) -> ContractAddress {
            self.strk_token.read()
        }

        fn set_drip_amount(ref self: ContractState, new_amount: u256) {
            assert(get_caller_address() == self.owner.read(), Errors::NOT_OWNER);
            let old = self.drip_amount.read();
            self.drip_amount.write(new_amount);
            self.emit(DripAmountUpdated { old_amount: old, new_amount });
        }

        fn set_cooldown(ref self: ContractState, new_cooldown: u64) {
            assert(get_caller_address() == self.owner.read(), Errors::NOT_OWNER);
            let old = self.cooldown_seconds.read();
            self.cooldown_seconds.write(new_cooldown);
            self.emit(CooldownUpdated { old_cooldown: old, new_cooldown });
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), Errors::NOT_OWNER);
            assert(!new_owner.is_zero(), Errors::ZERO_NEW_OWNER);
            let previous = self.owner.read();
            self.owner.write(new_owner);
            self.emit(OwnerTransferred { previous_owner: previous, new_owner });
        }
    }
}
