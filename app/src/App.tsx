import { useMemo, useState } from "react";
import { type Address, keccak256, stringToHex } from "viem";
import {
  useAccount,
  useConnect,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract
} from "wagmi";
import { celo } from "wagmi/chains";

const contractAddress = (import.meta.env.VITE_CONTRACT_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as Address;

const spendGuardAbi = [
  {
    type: "function",
    name: "setMonthlyLimit",
    stateMutability: "nonpayable",
    inputs: [{ name: "limitCents", type: "uint256" }],
    outputs: []
  },
  {
    type: "function",
    name: "recordSpend",
    stateMutability: "nonpayable",
    inputs: [
      { name: "merchantId", type: "bytes32" },
      { name: "amountCents", type: "uint256" },
      { name: "memo", type: "string" }
    ],
    outputs: []
  },
  {
    type: "function",
    name: "currentMonthKey",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint64" }]
  },
  {
    type: "function",
    name: "getMonthState",
    stateMutability: "view",
    inputs: [
      { name: "user", type: "address" },
      { name: "monthKey", type: "uint64" }
    ],
    outputs: [
      {
        name: "state",
        type: "tuple",
        components: [
          { name: "limitCents", type: "uint256" },
          { name: "spentCents", type: "uint256" },
          { name: "receiptCount", type: "uint32" }
        ]
      }
    ]
  }
] as const;

function formatCents(value?: bigint) {
  if (value === undefined) return "-";
  const dollars = value / 100n;
  const cents = value % 100n;
  return `$${dollars.toString()}.${cents.toString().padStart(2, "0")}`;
}

export default function App() {
  const { address, isConnected, chainId } = useAccount();
  const { connect, connectors } = useConnect();
  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const [limitCents, setLimitCents] = useState("5000");
  const [merchant, setMerchant] = useState("local-merchant");
  const [amountCents, setAmountCents] = useState("750");
  const [memo, setMemo] = useState("MiniPay spend proof");

  const merchantId = useMemo(() => keccak256(stringToHex(`merchant:${merchant}`)), [merchant]);

  const currentMonth = useReadContract({
    address: contractAddress,
    abi: spendGuardAbi,
    functionName: "currentMonthKey",
    query: { enabled: contractAddress !== "0x0000000000000000000000000000000000000000" }
  });

  const monthState = useReadContract({
    address: contractAddress,
    abi: spendGuardAbi,
    functionName: "getMonthState",
    args: address && currentMonth.data ? [address, currentMonth.data] : undefined,
    query: { enabled: Boolean(address && currentMonth.data) }
  });

  const state = monthState.data;
  const isReady = isConnected && chainId === celo.id;

  return (
    <main>
      <section className="hero">
        <p className="eyebrow">Celo / MiniPay proof</p>
        <h1>MiniPay Spend Guard</h1>
        <p>
          A non-custodial spend-limit and receipt layer for MiniPay-style payment workflows.
          It records payment intent, limits, and receipts without holding user funds.
        </p>
      </section>

      <section className="panel">
        <div className="status-row">
          <span>Contract</span>
          <code>{contractAddress}</code>
        </div>
        <div className="status-row">
          <span>Wallet</span>
          <code>{address ?? "Not connected"}</code>
        </div>
        <div className="status-row">
          <span>Celo Mainnet</span>
          <strong>{chainId === celo.id ? "Connected" : "Required"}</strong>
        </div>
        {!isConnected && (
          <button onClick={() => connect({ connector: connectors[0] })}>Connect Wallet</button>
        )}
      </section>

      <section className="grid">
        <form
          className="panel"
          onSubmit={(event) => {
            event.preventDefault();
            writeContract({
              address: contractAddress,
              abi: spendGuardAbi,
              functionName: "setMonthlyLimit",
              args: [BigInt(limitCents)]
            });
          }}
        >
          <h2>Set Spending Policy</h2>
          <label>
            Monthly limit, cents
            <input value={limitCents} onChange={(event) => setLimitCents(event.target.value)} />
          </label>
          <button disabled={!isReady || isPending}>Save Limit</button>
        </form>

        <form
          className="panel"
          onSubmit={(event) => {
            event.preventDefault();
            writeContract({
              address: contractAddress,
              abi: spendGuardAbi,
              functionName: "recordSpend",
              args: [merchantId, BigInt(amountCents), memo]
            });
          }}
        >
          <h2>Record Receipt</h2>
          <label>
            Merchant label
            <input value={merchant} onChange={(event) => setMerchant(event.target.value)} />
          </label>
          <label>
            Amount, cents
            <input value={amountCents} onChange={(event) => setAmountCents(event.target.value)} />
          </label>
          <label>
            Memo
            <input value={memo} onChange={(event) => setMemo(event.target.value)} />
          </label>
          <button disabled={!isReady || isPending}>Record Spend</button>
        </form>
      </section>

      <section className="panel metrics">
        <h2>Current Month</h2>
        <div>
          <span>Limit</span>
          <strong>{formatCents(state?.limitCents)}</strong>
        </div>
        <div>
          <span>Spent</span>
          <strong>{formatCents(state?.spentCents)}</strong>
        </div>
        <div>
          <span>Receipts</span>
          <strong>{state?.receiptCount?.toString() ?? "-"}</strong>
        </div>
      </section>

      {hash && (
        <section className="panel">
          <span>Transaction</span>
          <a href={`https://celoscan.io/tx/${hash}`} target="_blank" rel="noreferrer">
            {isConfirming ? "Confirming..." : isSuccess ? "Confirmed" : hash}
          </a>
        </section>
      )}
    </main>
  );
}
