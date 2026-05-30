#!/usr/bin/env bash
# Generate ABI JSON per contract for mobile + backend consumers.
# Output: abi-exports/<chain>/<ContractName>.json

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/abi-exports"

mkdir -p "$OUT/evm" "$OUT/solana" "$OUT/cosmos" "$OUT/starknet"

# ---------- EVM (Foundry) ----------
if command -v forge >/dev/null 2>&1; then
  echo ">> EVM: forge build + inspect"
  (cd "$ROOT/evm" && forge build --silent)
  for sol in "$ROOT"/evm/src/*.sol; do
    name="$(basename "$sol" .sol)"
    (cd "$ROOT/evm" && forge inspect "$name" abi --json) > "$OUT/evm/$name.json"
    echo "   wrote evm/$name.json"
  done
else
  echo "!! forge not found, skipping EVM ABI export"
fi

# ---------- Solana (Anchor IDL) ----------
if command -v anchor >/dev/null 2>&1; then
  echo ">> Solana: anchor build"
  (cd "$ROOT/solana" && anchor build)
  for idl in "$ROOT"/solana/target/idl/*.json; do
    [ -f "$idl" ] || continue
    name="$(basename "$idl")"
    cp "$idl" "$OUT/solana/$name"
    echo "   wrote solana/$name"
  done
else
  echo "!! anchor not found, skipping Solana IDL export"
fi

# ---------- Cosmos (cw-schema) ----------
if command -v cargo >/dev/null 2>&1; then
  echo ">> Cosmos: cargo run schema"
  for contract in "$ROOT"/cosmos/contracts/*/; do
    name="$(basename "$contract")"
    if [ -f "$contract/src/bin/schema.rs" ]; then
      (cd "$contract" && cargo run --quiet --bin schema)
      if [ -d "$contract/schema" ]; then
        mkdir -p "$OUT/cosmos/$name"
        cp -r "$contract/schema/." "$OUT/cosmos/$name/"
        echo "   wrote cosmos/$name/"
      fi
    fi
  done
else
  echo "!! cargo not found, skipping Cosmos schema export"
fi

# ---------- Starknet (Cairo / Scarb) ----------
# Scarb embeds the Cairo ABI inside the Sierra contract_class.json under `.abi`.
# We extract just that array so consumers can feed it straight to starknet.js.
if command -v scarb >/dev/null 2>&1; then
  echo ">> Starknet: scarb build + jq abi extract"
  (cd "$ROOT/starknet" && scarb build)
  for cls in "$ROOT"/starknet/target/dev/*.contract_class.json; do
    [ -f "$cls" ] || continue
    base="$(basename "$cls" .contract_class.json)"
    # Skip snforge test build artifacts (have .test. infix or test-mod prefix).
    case "$base" in
      *.test|*test_*) continue ;;
    esac
    # Strip the "<package>_" prefix Scarb prepends so the output name matches
    # the Cairo module/contract name (e.g. "devwallet_faucet_FaucetDispenser" -> "FaucetDispenser").
    name="${base#devwallet_faucet_}"
    # Skip the Scarb scaffold leftover.
    [ "$name" = "HelloStarknet" ] && continue
    jq '.abi' "$cls" > "$OUT/starknet/$name.json"
    echo "   wrote starknet/$name.json"
  done
else
  echo "!! scarb not found, skipping Starknet ABI export"
fi

echo ">> done. artifacts in $OUT"
