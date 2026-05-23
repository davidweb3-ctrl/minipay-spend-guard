# MiniPay Spend Guard

MiniPay Spend Guard is a small Celo/MiniPay-compatible payment-safety proof.

It lets a user set a monthly spending limit and record merchant spend receipts onchain. The contract does not custody funds, does not route payments, and rejects native CELO transfers. It is intended as a narrow Proof of Ship submission artifact for payment policy, transparency, and user-facing spend controls.

## Why This Exists

Celo Proof of Ship rewards shipped products with measurable Celo activity. This project is intentionally scoped as a low-risk MiniPay-adjacent utility:

- non-custodial by design;
- useful for payment and merchant workflows;
- small enough to deploy and test quickly;
- built with Foundry tests and a Vite/Wagmi frontend using `viem`, not `ethers.js`.

## Contracts

```text
src/MiniPaySpendGuard.sol
```

Core actions:

- `setMonthlyLimit(uint256 limitCents)`
- `recordSpend(bytes32 merchantId, uint256 amountCents, string memo)`
- `getMonthState(address user, uint64 monthKey)`

## Run Tests

```bash
forge test -vv
```

## Frontend

```bash
cd app
pnpm install
pnpm build
```

The frontend uses injected wallets through Wagmi. Set the deployed contract address before building:

```bash
cp .env.example .env
VITE_CONTRACT_ADDRESS=0xYourCeloContract
```

## Celo Mainnet Deployment

Use a fresh development wallet with only a tiny amount of CELO for gas.

```bash
export PRIVATE_KEY=0x...
forge script script/DeployCelo.s.sol:DeployCelo \
  --rpc-url https://forno.celo.org \
  --chain-id 42220 \
  --broadcast \
  --verify
```

Do not use a wallet containing personal funds for development.

## Proof of Ship Notes

This project is not a production wallet, audit framework, custodial product, or DeFi strategy. It is a working public proof for:

- Celo mainnet contract deployment;
- open-source GitHub activity;
- MiniPay-compatible frontend dependencies;
- simple real-user spend safety UX.
