import * as anchor from "@coral-xyz/anchor"
import { AnchorProvider, BN, Program, Wallet } from "@coral-xyz/anchor"
import { Connection, Keypair, PublicKey, clusterApiUrl } from "@solana/web3.js"
import * as fs from "fs"
import * as os from "os"
import * as path from "path"
import type { DevFaucet } from "../target/types/dev_faucet"
import idl from "../target/idl/dev_faucet.json"

/**
 * One-off bootstrap: initialize the FaucetState PDA + fund it on devnet.
 * Run via `bunx ts-node scripts/init-faucet.ts` (or any TS runner).
 *
 * Env overrides (optional):
 *   SOLANA_RPC_URL — default: clusterApiUrl("devnet")
 *   DRIP_LAMPORTS — default: 5_000_000 (0.005 SOL)
 *   COOLDOWN_SECONDS — default: 86_400
 *   FUND_LAMPORTS — default: 2_000_000_000 (2 SOL)
 *
 * Authority = keypair at ~/.config/solana/id.json (CLI default).
 */
async function main(): Promise<void> {
  const keypairPath = path.join(os.homedir(), ".config/solana/id.json")
  const raw = JSON.parse(fs.readFileSync(keypairPath, "utf8")) as number[]
  const authority = Keypair.fromSecretKey(Uint8Array.from(raw))

  const rpcUrl = process.env.SOLANA_RPC_URL ?? clusterApiUrl("devnet")
  const dripLamports = new BN(process.env.DRIP_LAMPORTS ?? "5000000")
  const cooldownSec = new BN(process.env.COOLDOWN_SECONDS ?? "86400")
  const fundLamports = new BN(process.env.FUND_LAMPORTS ?? "2000000000")

  const connection = new Connection(rpcUrl, "confirmed")
  const provider = new AnchorProvider(connection, new Wallet(authority), { commitment: "confirmed" })
  anchor.setProvider(provider)

  const program = new Program<DevFaucet>(idl as DevFaucet, provider)

  const [faucetPda, faucetBump] = PublicKey.findProgramAddressSync(
    [Buffer.from("faucet"), authority.publicKey.toBuffer()],
    program.programId
  )

  console.log("Authority:    ", authority.publicKey.toBase58())
  console.log("Program ID:   ", program.programId.toBase58())
  console.log("Faucet PDA:   ", faucetPda.toBase58(), "(bump", faucetBump, ")")

  const existing = await connection.getAccountInfo(faucetPda)
  if (existing === null) {
    console.log("→ Initializing faucet…")
    const txInit = await program.methods
      .initialize(dripLamports, cooldownSec)
      .accountsPartial({
        authority: authority.publicKey,
        faucet: faucetPda
      })
      .rpc()
    console.log("  init tx:", txInit)
  } else {
    console.log("→ Faucet already initialized, skipping init")
  }

  const balanceBefore = await connection.getBalance(faucetPda)
  console.log("Faucet balance before fund:", balanceBefore, "lamports")

  console.log("→ Funding faucet…")
  const txFund = await program.methods
    .fund(fundLamports)
    .accountsPartial({
      funder: authority.publicKey,
      faucet: faucetPda
    })
    .rpc()
  console.log("  fund tx:", txFund)

  const balanceAfter = await connection.getBalance(faucetPda)
  console.log("Faucet balance after fund: ", balanceAfter, "lamports")
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
