use anchor_lang::prelude::*;
use anchor_lang::system_program;
use crate::constants::{FAUCET_SEED, RECIPIENT_SEED};
use crate::error::FaucetError;
use crate::state::{FaucetState, RecipientRecord};

#[derive(Accounts)]
#[instruction(recipient: Pubkey)]
pub struct Drip<'info> {
    #[account(mut, address = faucet.authority @ FaucetError::NotAuthority)]
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [FAUCET_SEED, faucet.authority.as_ref()],
        bump = faucet.bump
    )]
    pub faucet: Account<'info, FaucetState>,

    #[account(
        init_if_needed,
        payer = authority,
        space = 8 + RecipientRecord::INIT_SPACE,
        seeds = [RECIPIENT_SEED, faucet.key().as_ref(), recipient.as_ref()],
        bump
    )]
    pub recipient_record: Account<'info, RecipientRecord>,

    /// CHECK: arbitrary recipient — funds are transferred to this account.
    #[account(mut, address = recipient)]
    pub recipient_account: UncheckedAccount<'info>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<Drip>, recipient: Pubkey) -> Result<()> {
    let clock = Clock::get()?;
    let now = clock.unix_timestamp;
    let faucet = &ctx.accounts.faucet;
    let record = &mut ctx.accounts.recipient_record;

    // First-drip → record bump + recipient. Existing record → enforce cooldown.
    if record.recipient == Pubkey::default() {
        record.recipient = recipient;
        record.bump = ctx.bumps.recipient_record;
    } else {
        let next_available = record.last_drip_at + faucet.cooldown_seconds;
        require!(now >= next_available, FaucetError::CooldownActive);
    }

    // The faucet PDA owns its own SOL balance (no separate vault account).
    // Direct lamport debit/credit between system-program owned accounts is
    // safe; the faucet PDA was created via `system_program::create_account`
    // and remains system-owned for the simple SOL-only use case.
    let faucet_balance = faucet.to_account_info().lamports();
    require!(faucet_balance >= faucet.drip_amount, FaucetError::FaucetEmpty);

    // Use lamport mutation directly (faucet PDA owned by the program after
    // init, so it can debit its own lamports).
    **faucet.to_account_info().try_borrow_mut_lamports()? -= faucet.drip_amount;
    **ctx.accounts.recipient_account.try_borrow_mut_lamports()? += faucet.drip_amount;

    record.last_drip_at = now;
    msg!(
        "Dripped {} lamports to {} (next available at {})",
        faucet.drip_amount,
        recipient,
        now + faucet.cooldown_seconds
    );
    Ok(())
}

#[derive(Accounts)]
pub struct Fund<'info> {
    #[account(mut)]
    pub funder: Signer<'info>,

    #[account(
        mut,
        seeds = [FAUCET_SEED, faucet.authority.as_ref()],
        bump = faucet.bump
    )]
    pub faucet: Account<'info, FaucetState>,

    pub system_program: Program<'info, System>,
}

pub fn fund_handler(ctx: Context<Fund>, amount: u64) -> Result<()> {
    let cpi_ctx = CpiContext::new(
        ctx.accounts.system_program.key(),
        system_program::Transfer {
            from: ctx.accounts.funder.to_account_info(),
            to: ctx.accounts.faucet.to_account_info(),
        },
    );
    system_program::transfer(cpi_ctx, amount)?;
    msg!("Funded faucet {} with {} lamports", ctx.accounts.faucet.key(), amount);
    Ok(())
}
