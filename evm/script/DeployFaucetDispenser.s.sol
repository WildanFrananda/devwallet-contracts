// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {FaucetDispenser} from "../src/FaucetDispenser.sol";

/**
 * @notice Deploys FaucetDispenser to the configured RPC, funded with the
 *         `FUND_AMOUNT_WEI` constructor msg.value.
 *
 * Env vars required:
 *   - PRIVATE_KEY: sponsor wallet private key (hex, 0x-prefixed)
 *   - RPC_URL: target RPC (e.g. https://1rpc.io/sepolia)
 *   - DRIP_WEI: per-recipient drip amount (e.g. 50000000000000000 for 0.05 ETH)
 *   - COOLDOWN_SEC: cooldown between drips per recipient (e.g. 86400)
 *   - FUND_AMOUNT_WEI: how much to send at deploy time (must be <= sponsor balance)
 *
 * Usage:
 *   forge script script/DeployFaucetDispenser.s.sol:DeployFaucetDispenser \
 *     --rpc-url $RPC_URL --broadcast --legacy
 */
contract DeployFaucetDispenser is Script {
    function run() external returns (FaucetDispenser dispenser) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 dripWei = vm.envUint("DRIP_WEI");
        uint256 cooldownSec = vm.envUint("COOLDOWN_SEC");
        uint256 fundAmountWei = vm.envUint("FUND_AMOUNT_WEI");

        vm.startBroadcast(deployerKey);
        dispenser = new FaucetDispenser{value: fundAmountWei}(dripWei, cooldownSec);
        vm.stopBroadcast();

        console2.log("FaucetDispenser deployed at:", address(dispenser));
        console2.log("Owner:", dispenser.owner());
        console2.log("Drip amount (wei):", dispenser.dripAmount());
        console2.log("Cooldown (sec):", dispenser.cooldown());
        console2.log("Initial balance (wei):", address(dispenser).balance);
    }
}
