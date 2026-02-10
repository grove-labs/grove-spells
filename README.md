# 🌳🪄 Grove Spells

**Governance Spells for Grove**

## ✨ Spells

The latest spells can be found in the `src/proposals/` directory. Spells are organized by date in YYYYMMDD format, with separate files for each network (i.e. `GroveEthereum_20250724.sol`).

## 🧪 Tests

### 📋 Prerequisites

1. **RPC Endpoints with Historical Block Support**

   Tests fork from historical block timestamps, so you need RPC endpoints that support archive data. Free-tier RPC providers not always support historical state queries

   Set the following environment variables:
   ```bash
   export ETH_RPC_URL="your-ethereum-mainnet-rpc-url" # Ethereum Mainnet
   export BASE_RPC_URL="your-base-rpc-url"            # Base
   export AVALANCHE_RPC_URL="your-avalanche-rpc-url"  # Avalanche
   export PLUME_RPC_URL="your-plume-rpc-url"          # Plume
   ```

2. **Etherscan API Key (Paid Tier Required)**

   Tests use Etherscan's API to fetch block numbers for a given date. Each test specifies a date (e.g., `setupDomains("2026-01-27T12:00:00Z")`), which is converted to a Unix timestamp and used to query the Etherscan API for the corresponding block number on each supported chain. The test then forks from that specific block

   A paid Etherscan API key is required to access that feature

   ```bash
   export ETHERSCAN_API_KEY="your-api-key"
   ```

   **Note:** Chains not supported by Etherscan's API (e.g., Plume) have hardcoded block numbers in the spell runner (`src/test-harness/SpellRunner.sol`).

### 🚀 Running Tests

```bash
# Install dependencies
forge install

# Run all tests
forge test

# Check Foundry documentation to learn about all test-running options
forge test --help
```

## 📦 Archive

The `archive/` directory stores all historical spells that have been executed on-chain. Each archived spell includes:
- The spell contract files (e.g., `GroveEthereum_YYYYMMDD.sol`)
- The PR description (`YYYYMMDD.md`) documenting the intended changes, addresses, and deployment info
- The corresponding test file (`GroveEthereum_YYYYMMDD.t.sol`) used to test the spell at the time of its deployment

**Note:** Archived spells may not compile or run tests with the current codebase, as they may depend on older versions of helper libraries or test harnesses. If you need to run tests for a historical spell, checkout the git commit from when that spell was in the `src/proposals/` directory.
