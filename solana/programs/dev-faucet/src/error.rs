use anchor_lang::prelude::*;

#[error_code]
pub enum FaucetError {
    #[msg("Cooldown still active for this recipient")]
    CooldownActive,
    #[msg("Faucet PDA does not hold enough lamports for a drip")]
    FaucetEmpty,
    #[msg("Signer is not the configured faucet authority")]
    NotAuthority,
}
