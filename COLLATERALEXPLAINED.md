# Decentralized Stablecoin Liquidation Process

This README explains the liquidation process of collateralized stablecoins (e.g., DAI) and the mechanics of how liquidators can participate when the collateralization ratio falls below the required threshold. The collateral is usually in the form of ERC-20 tokens (e.g., WBTC for Bitcoin) and can be liquidated by investors if the collateral value drops too low.

## Overview

When users deposit collateral (such as WBTC or ETH) and mint stablecoins (like DAI), they must maintain a minimum collateralization ratio (e.g., 150%). If the value of their collateral falls below this threshold, the system initiates liquidation. Liquidators can pay the debt in DAI and receive collateral in return.

### Key Terms:

- **Collateral**: The asset deposited (e.g., WBTC or ETH).
- **DAI**: The minted stablecoin that is borrowed against collateral.
- **Liquidator**: An investor who repays the debt to the system and receives collateral at a discount.
- **Threshold**: The minimum collateralization ratio required (e.g., 150%).

---

## Liquidation Process (Step-by-Step)

| **Step**                    | **Description**                                                                                                                                   | **Example (ETH)**                                                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **1. Collateral Deposit**   | User deposits 150% collateral (e.g., $150 worth of ETH) and mints $100 worth of DAI.                                                              | User deposits 1.5 ETH (worth $150) and borrows 100 DAI.                                                                |
| **2. Price Drop**           | The value of the collateral (ETH) falls below the 150% threshold. For instance, ETH drops to $74.                                                 | ETH price drops to $74, causing the collateralization ratio to fall below 150%.                                        |
| **3. Liquidation**          | Liquidators can now step in and pay the $50 worth of DAI to repay the debt. In return, they receive $74 worth of ETH (the discounted collateral). | A liquidator pays 50 DAI to the system and receives 1 ETH (worth $74).                                                 |
| **4. Remaining Collateral** | The liquidator gets the collateral (ETH/WBTC) and any remaining collateral (if any) is returned to the original depositor.                        | If there is any remaining collateral after repaying the debt, the depositor gets it back (e.g., 0.5 ETH in this case). |
| **5. Burning DAI**          | The DAI used by the liquidator to pay off the debt is burned, keeping the supply stable.                                                          | 50 DAI used to repay the debt is burned by the system, reducing the total supply.                                      |

---

## Example Scenario: Liquidation

1. **Initial Deposit**:

   - User deposits 1.5 ETH (worth $150) and borrows 100 DAI.

2. **Price Drop**:

   - ETH drops in price to $74, which reduces the collateral value below the 150% required ratio.

3. **Liquidation by Liquidator**:

   - Liquidator sees an opportunity and pays $50 worth of DAI to settle the debt.
   - Liquidator receives 1 ETH (worth $74) in return for paying off the debt.

4. **Burning DAI**:
   - The 50 DAI used by the liquidator is burned, decreasing the circulating supply of DAI.

---

## Key Points:

- The system ensures that the collateral remains sufficient to back the minted stablecoins.
- If the collateral value decreases significantly, liquidators can pay off the debt and acquire the discounted collateral.
- DAI is burned when used to repay the debt, keeping the supply stable.

---

## Conclusion

This process ensures that the stablecoin system remains solvent while providing opportunities for liquidators to profit from distressed collateral. The protocol dynamically adjusts to market conditions by managing collateral and debt through liquidation when needed.

---

For more details, feel free to check the implementation in the [Decentralized Stablecoin Smart Contract](https://github.com/your-repo-link).
