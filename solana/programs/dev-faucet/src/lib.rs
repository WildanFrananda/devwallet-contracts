pub mod constants;
pub mod error;
pub mod instructions;
pub mod state;

use anchor_lang::prelude::*;

pub use instructions::*;

declare_id!("2UhnWRa3Pu4BqTN7xnZG9jxkmz3cgCEC2AF2Jh5MKgCY");

#[program]
pub mod dev_faucet {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, drip_amount: u64, cooldown_seconds: i64) -> Result<()> {
        initialize::handler(ctx, drip_amount, cooldown_seconds)
    }

    pub fn drip(ctx: Context<Drip>, recipient: Pubkey) -> Result<()> {
        drip::handler(ctx, recipient)
    }

    pub fn fund(ctx: Context<Fund>, amount: u64) -> Result<()> {
        drip::fund_handler(ctx, amount)
    }
}
