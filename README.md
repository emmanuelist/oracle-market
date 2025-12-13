# Oracle Market - Decentralized Prediction Platform

![Stacks](https://img.shields.io/badge/Stacks-Clarity%204-purple)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Development-orange)

##  Overview

**Oracle Market** is a professional-grade, decentralized prediction market built on the Stacks blockchain. It enables users to stake STX on real-world event outcomes, with resolutions verified by trusted oracles. This project leverages **Clarity 4** to ensure robust security, predictability, and efficiency.

KEY FEATURES:
-   **Trusted Resolution**: Markets are resolved by designated verified oracles.
-   **Secure Staking**: Non-custodial staking using native STX.
-   **Dynamic Odds**: Real-time odds calculation based on pool sizes.
-   **Soulbound Achievements**: NFT-based reputation system for top predictors.
-   **Admin Controls**: Comprehensive management tools for market integrity.

##  Getting Started

### Prerequisites

-   [Clarinet](https://github.com/hirosystems/clarinet) (Latest Version)
-   Node.js & NPM

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/oracle-market.git
    cd oracle-market
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    ```

### Running Tests

We use Vitest with the Clarinet SDK for comprehensive testing.

```bash
npm run test
```

##  Architecture

The core of the platform is the `oracle-market` smart contract.

### Smart Contract: `oracle-market.clar`

-   **State Management**: Tracks markets, user stakes, and global configuration.
-   **Market Lifecycle**:
    1.  `active`: Open for staking.
    2.  `locked`: Staking closed, awaiting outcome.
    3.  `resolved`: Outcome set, winnings claimable.
    4.  `cancelled`: Invalid market, refunds enabled.
-   **Fees**: Configurable platform fee (default 3%) on pot resolution.

#### Key Functions

| Function | Type | Description |
| :--- | :--- | :--- |
| `create-market` | Admin | Initialise a new prediction market. |
| `place-stake` | Public | Stake STX on a specific outcome. |
| `resolve-market` | Oracle | Declare the winning outcome. |
| `claim-winnings` | Public | Withdraw winnings after resolution. |
| `update-market` | Admin | Update market details before activation. |

##  Tech Stack

-   **Blockchain**: Stacks (Layer 2 for Bitcoin)
-   **Contract Language**: Clarity 4
-   **Testing framework**: Vitest + Clarinet SDK

##  License

This project is licensed under the MIT License.
