# CLAUDE.md — devwallet-contracts

## Purpose
Multi-chain smart contracts for DevWallet (testnet-only): EVM faucet dispenser, Solana faucet program, CosmWasm faucet contract. ABIs / IDLs / schemas are exported to `abi-exports/` for the backend + mobile to consume.

## Stack
- EVM: Foundry (`forge`, `cast`) + Solidity ^0.8.20 + OpenZeppelin contracts
- Solana: Anchor 0.30+ + Rust 1.78 + Solana CLI 1.18.x (program name = `dev_faucet`, lib = `dev_faucet`)
- Cosmos: CosmWasm (`cw-template`-based contract `dev-faucet`) + Rust 1.78 + `wasm32-unknown-unknown` target
- TypeScript only inside `solana/` (Anchor tests / scripts). Solidity + Rust handled by their own toolchains.

## Layout
```
evm/                  # Foundry project (src/, test/, script/, lib/)
solana/               # Anchor workspace (programs/dev-faucet/, Anchor.toml)
cosmos/contracts/dev-faucet/   # CosmWasm standalone contract
scripts/export-abi.sh # exports ABIs / IDLs / schemas → abi-exports/
abi-exports/
  evm/<Contract>.json
  solana/<program>.json
  cosmos/<contract>/...
```

## Conventions
- Conventional Commits required
- EVM: `forge fmt` + custom errors (no string reverts) + SPDX `MIT`
- Solana: `cargo fmt` + Anchor declare_id synced via `anchor keys sync`
- Cosmos: `cargo fmt` + `cargo clippy -D warnings`
- ESLint flat config only in `solana/eslint.config.mjs` (TS scripts/tests). EVM + Cosmos use native linters.
- Toolchain pins: Foundry latest, Anchor 0.30.1, Solana CLI 1.18.26, Rust 1.78.

## Forbidden
- Do not add mainnet-only code. Testnet only.
- Do not commit `target/`, `cache/`, `out/`, `.anchor/`, `test-ledger/`, `artifacts/`, `schema/` — all git-ignored.
- Do not hand-edit `abi-exports/` — regenerate via `scripts/export-abi.sh`.
- Do not rename the Solana program from `dev_faucet` without updating `Anchor.toml`, `lib.rs`, `Cargo.toml` `lib.name`, and the test crate path.
- Do not commit hot signing keys. `solana-keygen new` outputs go in user `~/.config/solana/`, not the repo.
