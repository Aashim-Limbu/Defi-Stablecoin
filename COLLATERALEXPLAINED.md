# DAI Liquidation Process

This document explains the liquidation process for the DAI stablecoin system, detailing the roles of key actors, their actions, and the financial flow during a liquidation event.

---

## **Overview**

DAI is an algorithmic stablecoin maintained by the MakerDAO protocol, backed by collateral assets such as ETH. When the collateral value drops below the required **collateralization ratio (CR)**, a liquidation process is triggered to ensure system stability.

### **Key Actors**

1. **Borrower**: Provides collateral to mint DAI and risks liquidation if the collateral value falls.
2. **Liquidator**: Buys discounted collateral during liquidation auctions.
3. **MakerDAO Protocol**: Manages the process to maintain DAI's stability.

---

## **Step-by-Step Liquidation Process**

### **1. Auction Starts**

- **Scenario**: Borrower deposited **2 ETH** (initial price: $2,000/ETH) as collateral to mint **2,000 DAI**.

  - Initial collateral value: `$2,000 × 2 = $4,000`
  - Debt created: `2,000 DAI`
  - Collateralization Ratio: `200%` (safe above 150%).

- **Price Drop**: ETH price falls to `$1,200/ETH`.

  - New collateral value: `$1,200 × 2 = $2,400`
  - New Collateralization Ratio: `2,400 / 2,000 = 120%` (below the threshold of 150%).

- **Liquidation Trigger**: MakerDAO starts a collateral auction for **2 ETH**.

  **Debt Calculation with Penalty**:

  ```
  Total Debt = Debt × (1 + Liquidation Penalty)
             = 2,000 DAI × 1.13
             = 2,260 DAI
  ```

---

### **2. Liquidator Buys Collateral**

- Liquidators bid DAI to purchase collateral.
- **Winning Bid**: `2,260 DAI for 2 ETH`.
- Effective ETH Price for Liquidator:
  ```
  Price per ETH = 2,260 DAI / 2 ETH = 1,130 USD/ETH
  ```

---

### **3. Protocol Resolves Debt**

- The **2,260 DAI** paid by the liquidator is distributed as:

  1. **2,000 DAI** repays the borrower’s debt.
  2. **260 DAI** (13% liquidation penalty) goes to MakerDAO’s surplus buffer.

- Surplus collateral is returned to the borrower:
  ```
  Surplus USD = Collateral Value - Liquidation Debt
              = 2,400 USD - 2,260 USD = 140 USD
  Surplus ETH = 140 USD / 1,200 USD/ETH = 0.1167 ETH
  ```

---

## **Summary Table**

| **Actor**            | **Action**                           | **Value**                      |
| -------------------- | ------------------------------------ | ------------------------------ |
| **Borrower**         | Deposits 2 ETH, mints 2,000 DAI      | $4,000 collateral, $2,000 debt |
| **Price Drop**       | ETH drops to $1,200                  | Collateral now worth $2,400    |
| **Liquidation Debt** | Total owed w/ penalty                | 2,260 DAI                      |
| **Liquidator**       | Buys 2 ETH at discount               | Pays 2,260 DAI, gets 2 ETH     |
| **MakerDAO Surplus** | Gains liquidation penalty            | 260 DAI                        |
| **Borrower Surplus** | Receives remaining ETH after auction | 0.1167 ETH                     |

---

## **Conclusion**

The MakerDAO liquidation process ensures DAI's stability by efficiently auctioning undercollateralized positions. Borrowers must monitor collateral values to avoid liquidation penalties, while liquidators profit by purchasing discounted assets.

For more details, visit the [MakerDAO Documentation](https://docs.makerdao.com/).
