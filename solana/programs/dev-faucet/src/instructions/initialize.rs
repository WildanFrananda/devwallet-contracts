use anchor_lang::prelude::*;
use crate::constants::FAUCET_SEED;
use crate::state::FaucetState;

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + FaucetState::INIT_SPACE,
        seeds = [FAUCET_SEED, authority.key().as_ref()],
        bump
    )]
    pub faucet: Account<'info, FaucetState>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<Initialize>, drip_amount: u64, cooldown_seconds: i64) -> Result<()> {
    let faucet = &mut ctx.accounts.faucet;
    faucet.authority = ctx.accounts.authority.key();
    faucet.drip_amount = drip_amount;
    faucet.cooldown_seconds = cooldown_seconds;
    faucet.bump = ctx.bumps.faucet;
    msg!(
        "Faucet initialized authority={} drip={} cooldown={}s",
        faucet.authority,
        faucet.drip_amount,
        faucet.cooldown_seconds
    );
    Ok(())
}
