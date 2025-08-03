# 🧠 Account Abstraction on zkSync & Ethereum Mainnet (ERC-4337)

This project demonstrates two approaches to Account Abstraction (AA):

- ✅ **zkSync Native Account Abstraction**: Leveraging built-in protocol support for smart accounts.
- ✅ **Ethereum Mainnet with ERC-4337**: Deploying a `MinimalAccount` smart wallet and interacting via UserOperations.

---

## ✨ Features

- 🔐 Smart wallet implementation using custom ownership logic
- 📝 Signature validation using `ecrecover`
- 🔁 Nonce tracking and replay protection
- ⚙️ Supports `validateTransaction()` (zkSync) and `validateUserOp()` (ERC-4337)
- 📜 Ownership transfer and native transaction signing

---

## 🛠️ Technologies

| Layer | Ethereum Mainnet | zkSync |
|------|------------------|--------|
| Account Type | ERC-4337 `MinimalAccount` | Native Smart Account |
| EntryPoint | Custom EntryPoint contract | Handled by zkSync protocol |
| Bundler | Optional (via user op sender) | zkSync node natively bundles |
| Signature | EIP-191 or custom | zkSync `Transaction` struct signature |

---

## 🧪 How It Works

### ✅ zkSync AA Flow

1. Deploy a smart account inheriting `IAccount`.
2. Implement `validateTransaction()`.
3. Sign transaction using the owner's private key.
4. Submit it directly — no bundler needed.
5. zkSync node verifies ownership and executes.

### ✅ Ethereum AA Flow (ERC-4337)

1. Deploy an `EntryPoint` and `MinimalAccount` contract.
2. Create a valid `UserOperation`.
3. Sign the operation hash with the wallet’s private key.
4. Send the operation to a bundler or simulate it via script.
5. EntryPoint verifies and routes the operation.

---

## 🚀 Getting Started

```bash
git clone https://github.com/yourusername/account-abstraction-zksync-eth.git
cd account-abstraction-zksync-eth
forge install
forge build

To test zkSync-specific features:

source .env
forge test --fork-url $ZKSYNC_RPC_URL

To test on Ethereum (via Anvil):

forge test --fork-url $MAINNET_RPC_URL
```

📁 Project Structure

contracts/
├── ethereum/
│   └── MinimalAccount.sol
├── zksync/
│   └── ZkSyncMinimalAccount.sol
test/
│   └── MinimalAccountTest.t.sol
│   └──ZksyncMinimalAccountTest.t.sol
scripts/
│   └── DeployMinimalAccount.s.sol
│   └──HelpUserConfig.s.sol
│   └──SendUserOps.s.sol

🧑‍💻 Author

@AL-Ayaan-Ansari
Built as a deep dive into modern Ethereum & zkRollup AA design patterns.
