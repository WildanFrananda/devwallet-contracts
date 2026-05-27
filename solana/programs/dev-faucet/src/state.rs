use anchor_lang::prelude::*;

/// Global faucet config + native SOL vault. Stored at PDA derived from
/// (FAUCET_SEED, authority). The account itself holds the SOL that `drip`
/// transfers to recipients.
#[account]
#[derive(InitSpace)]
pub struct FaucetState {
    pub authority: Pubkey,
    pub drip_amount: u64,
    pub cooldown_seconds: i64,
    pub bump: u8,
}

/// Per-recipient cooldown tracker. Stored at PDA
/// (RECIPIENT_SEED, faucet, recipient).
#[account]
#[derive(InitSpace)]
pub struct RecipientRecord {
    pub recipient: Pubkey,
    pub last_drip_at: i64,
    pub bump: u8,
}
