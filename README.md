# devwallet-contracts

Multi-chain smart contracts for [DevWallet](https://github.com/WildanFrananda) — testnet-only faucet dispensers. EVM (Foundry) + Solana (Anchor) + Cosmos (CosmWasm).

## Layout

```
evm/                          # Foundry project
  src/FaucetDispenser.sol
  test/FaucetDispenser.t.sol
solana/                       # Anchor workspace
  programs/dev-faucet/        # Rust program (lib = dev_faucet)
  Anchor.toml
cosmos/contracts/dev-faucet/  # CosmWasm standalone contract
scripts/export-abi.sh         # exports ABI / IDL / schema → abi-exports/
abi-exports/{evm,solana,cosmos}/
```

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Foundry | latest | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| Rust | 1.78.0 | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Solana CLI | 1.18.26 | `sh -c "$(curl -sSfL https://release.anza.xyz/v1.18.26/install)"` |
| Anchor CLI | 0.30.1 | `cargo install --locked --version 0.30.1 anchor-cli` |
| wasm32 target | — | `rustup target add wasm32-unknown-unknown` |

## Quick start

### EVM

```bash
cd evm
forge install                 # pulls forge-std + openzeppelin submodules
forge build
forge test -vvv
```

### Solana

```bash
cd solana
anchor keys sync              # only if program-id mismatch warning appears
anchor build
cargo test --workspace        # runs litesvm-based integration test
```

### Cosmos

```bash
cd cosmos/contracts/dev-faucet
cargo test
cargo build --release --target wasm32-unknown-unknown
```

## Export ABI / IDL / schema

```bash
./scripts/export-abi.sh
# Output:
#   abi-exports/evm/FaucetDispenser.json
#   abi-exports/solana/dev_faucet.json
#   abi-exports/cosmos/dev-faucet/{instantiate_msg,execute_msg,query_msg,...}.json
```

Script gracefully skips chains whose toolchain is missing locally — CI runs the full set.

## CI

| Workflow | Triggers on |
|---|---|
| `.github/workflows/ci-evm.yml` | `evm/**` paths |
| `.github/workflows/ci-solana.yml` | `solana/**` paths |
| `.github/workflows/ci-cosmos.yml` | `cosmos/**` paths |

## Conventions

- EVM: SPDX `MIT`, Solidity ^0.8.20, custom errors (no string reverts), `forge fmt`
- Solana: `cargo fmt`, program name pinned to `dev_faucet` (lib + `#[program]`)
- Cosmos: `cargo fmt` + `cargo clippy -D warnings`
- See [CLAUDE.md](CLAUDE.md) for full rules + forbidden patterns

## License

MIT — see [LICENSE](LICENSE)
