import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import {
  Account,
  RpcProvider,
  CallData,
  cairo,
  hash,
  Contract,
  type Abi,
  type CairoAssembly,
  type Calldata,
  type CompiledSierra
} from "starknet"

/**
 * One-off deploy: declare (if needed) + deploy the FaucetDispenser Cairo
 * contract on Starknet Sepolia, then fund it with STRK so it can drip.
 *
 * Env vars required:
 *   STARKNET_RPC_URL       — Sepolia RPC (e.g. https://starknet-sepolia.drpc.org)
 *   STARKNET_SPONSOR_ADDR  — funded OZ account address (hex)
 *   STARKNET_SPONSOR_KEY   — sponsor private key (hex, 0x-prefixed)
 *
 * Optional:
 *   STRK_TOKEN_ADDRESS   — default: Sepolia STRK ERC-20
 *   DRIP_AMOUNT_WEI      — default: 1 STRK  (1_000_000_000_000_000_000)
 *   COOLDOWN_SECONDS     — default: 86_400 (24h)
 *   FUND_AMOUNT_WEI      — default: 50 STRK
 *
 * Run: `bun run scripts/deploy-faucet.ts`
 */

const STRK_SEPOLIA = "0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D"
const DEFAULT_DRIP_WEI = 1_000_000_000_000_000_000n
const DEFAULT_COOLDOWN = 86_400n
const DEFAULT_FUND_WEI = 50_000_000_000_000_000_000n

function requireEnv(key: string): string {
  const v = process.env[key]
  if (!v) throw new Error(`missing env: ${key}`)
  return v
}

function bigintFromEnv(key: string, fallback: bigint): bigint {
  const v = process.env[key]
  return v ? BigInt(v) : fallback
}

async function main(): Promise<void> {
  const rpcUrl = requireEnv("STARKNET_RPC_URL")
  const sponsorAddress = requireEnv("STARKNET_SPONSOR_ADDR")
  const sponsorKey = requireEnv("STARKNET_SPONSOR_KEY")
  const strkAddress = process.env.STRK_TOKEN_ADDRESS ?? STRK_SEPOLIA
  const dripWei = bigintFromEnv("DRIP_AMOUNT_WEI", DEFAULT_DRIP_WEI)
  const cooldownSec = bigintFromEnv("COOLDOWN_SECONDS", DEFAULT_COOLDOWN)
  const fundWei = bigintFromEnv("FUND_AMOUNT_WEI", DEFAULT_FUND_WEI)

  const provider = new RpcProvider({ nodeUrl: rpcUrl })
  const sponsor = new Account({ provider, address: sponsorAddress, signer: sponsorKey })

  const targetDir = resolve(__dirname, "..", "target", "dev")
  const sierra = JSON.parse(
    readFileSync(`${targetDir}/devwallet_faucet_FaucetDispenser.contract_class.json`, "utf8")
  ) as CompiledSierra
  const casm = JSON.parse(
    readFileSync(`${targetDir}/devwallet_faucet_FaucetDispenser.compiled_contract_class.json`, "utf8")
  ) as CairoAssembly

  console.log("Sponsor    :", sponsorAddress)
  console.log("RPC        :", rpcUrl)
  console.log("STRK token :", strkAddress)
  console.log("Drip (wei) :", dripWei.toString())
  console.log("Cooldown   :", cooldownSec.toString(), "s")
  console.log("Funding    :", fundWei.toString(), "wei")

  console.log("→ declareIfNot…")
  const declareTx = await sponsor.declareIfNot({
    contract: sierra,
    casm: casm
  })
  if (declareTx.transaction_hash) {
    await provider.waitForTransaction(declareTx.transaction_hash)
  }
  const classHash = declareTx.class_hash
  console.log("  classHash =", classHash)

  const calldata: Calldata = CallData.compile({
    owner: sponsorAddress,
    strk_token: strkAddress,
    drip_amount: cairo.uint256(dripWei),
    cooldown_seconds: cooldownSec.toString()
  })

  // Pre-compute address so funding can land before the deploy receipt.
  const salt = "0x0"
  const predicted = hash.calculateContractAddressFromHash(salt, classHash, calldata, sponsorAddress)
  console.log("Predicted contract address:", predicted)

  console.log("→ deploy…")
  const deployTx = await sponsor.deployContract({
    classHash,
    constructorCalldata: calldata,
    salt,
    unique: true
  })
  await provider.waitForTransaction(deployTx.transaction_hash)
  const contractAddress = deployTx.contract_address
  console.log("  deployed at =", contractAddress)

  console.log("→ funding faucet with STRK…")
  const strkAbi: Abi = [
    {
      type: "function",
      name: "transfer",
      inputs: [
        { name: "recipient", type: "core::starknet::contract_address::ContractAddress" },
        { name: "amount", type: "core::integer::u256" }
      ],
      outputs: [{ type: "core::bool" }],
      state_mutability: "external"
    }
  ]
  const strk = new Contract({ abi: strkAbi, address: strkAddress, providerOrAccount: sponsor })
  const fundTx = await strk.invoke("transfer", [contractAddress, cairo.uint256(fundWei)])
  await provider.waitForTransaction(fundTx.transaction_hash)
  console.log("  fund tx =", fundTx.transaction_hash)

  console.log("\nDeploy complete.\n  STARKNET_FAUCET_CONTRACT =", contractAddress)
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
