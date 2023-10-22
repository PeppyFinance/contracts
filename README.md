# Peppy Finance Smart Contracts

## Deployment

- TradePair: [0xFA4DE5e7dfb2bD60C6Fda0f5D575b5F3F9F2e9Ac](https://explorer.evm.testnet.shimmer.network/address/0xFA4DE5e7dfb2bD60C6Fda0f5D575b5F3F9F2e9Ac)
- LiquidityPool: [0xB66C2A973a97EBbC03d2b089792dd8A7baab91F9](https://explorer.evm.testnet.shimmer.network/address/0xB66C2A973a97EBbC03d2b089792dd8A7baab91F9)
- PriceFeed: [0x6B514aB4eD47Ac370e5595f09752BB224e9Af5fF](https://explorer.evm.testnet.shimmer.network/address/0x6B514aB4eD47Ac370e5595f09752BB224e9Af5fF)
- FaucetToken (fake Stablecoin for collateral): [0xdAe024AD7eeE95ceC83F4df5C5DB06A8298b550E](https://explorer.evm.testnet.shimmer.network/address/0xdAe024AD7eeE95ceC83F4df5C5DB06A8298b550E)
- FaucetToken (fake Ethereum, only used for address): [0x8367300Db88A504Cef44c02d72740f2763eC6e9A](https://explorer.evm.testnet.shimmer.network/address/0x8367300Db88A504Cef44c02d72740f2763eC6e9A)

For local development make sure to add an `.env` and add the following env vars:

```bash
RPC_URL=http://localhost:8545/
PRIVATE_KEY=my-priv-key
PUBLIC_ADDR=my-pub-key
PYTH_ADDR=pyth-addr
```

And run `anvil` with the `--fork-url` flag and specify which chain should be forked. It is then important
to match `PYTH_ADDR` with the actual address on the forked chain.

## Documentation

### TradePair Contract

`TradePair` is a smart contract designed for opening, managing, and closing leveraged trading positions on an underlying asset. It also incorporates mechanisms for position liquidation and fee management.

#### Key Features

- **Open Positions**: Users can open leveraged long or short positions.
- **Close Positions**: Positions can be closed by the owner, realizing profits or losses.
- **Liquidate Positions**: Underwater positions can be liquidated by any user for a reward.
- **Fee Management**: Accumulates borrow and funding fees over time.

#### Public Variables

- **collateralToken**: Token used as collateral for positions.
- **priceFeed**: Provides the current price of the underlying asset.
- **liquidityPool**: Source of liquidity for the contract.

#### Core Functions

- **openPosition**: Opens a new trading position using collateral.
- **closePosition**: Closes an existing position.
- **liquidatePosition**: Liquidates an underwater position, rewarding the liquidator.
- **getPositionDetails**: Returns detailed information about a position.
- **updateFeeIntegrals**: Updates the accumulated borrow and funding fees.

#### Events

- **PositionOpened**: Triggered when a position is opened.
- **PositionClosed**: Triggered when a position is closed.
- **PositionLiquidated**: Triggered when a position is liquidated.

#### Private and Internal Functions

- **\_dropPosition**: Efficiently removes a user's position from the mapping and array storage. It requires the `id` and `owner` of the position as parameters.
- **\_getValue**: Calculates the current value of a position given the current price. It requires the `id` of the position and the current `price` as parameters.
- **\_getPrice**: Retrieves the latest price for the underlying asset from the price feed. It may use optional `_priceUpdateData` as a parameter.
- **\_calculateFundingRate**: Computes the funding rate based on the skew between long and short open interests.
- **\_calculateBorrowRate**: Determines the borrow rate based on the pool's utilization.

### LiquidityPool Contract

`LiquidityPool` is a contract responsible for managing the liquidity provided by users. It interacts with the `TradePair` contract to facilitate the provision and redemption of liquidity. Users can deposit assets into the pool and receive liquidity pool tokens (LPTs) in return, which can later be redeemed for the underlying asset.

#### Key Features

- **Deposits and Redemptions**: Allows users to deposit assets and earn LPTs. LPTs can be redeemed for the underlying assets.
- **Interaction with TradePair**: Works closely with the `TradePair` contract to handle payouts and fee integrals.
- **Flexible Borrow Rate**: Can set a maximum hourly borrow rate.

#### Public Variables

- **asset**: The underlying asset token that can be deposited into the liquidity pool.
- **maxBorrowRate**: The maximum hourly rate at which assets can be borrowed.
- **tradePair**: The associated `TradePair` contract address which the liquidity pool interacts with.

#### Core Functions

- **deposit**: Allows users to deposit assets into the liquidity pool in exchange for LPTs.
- **redeem**: Enables users to redeem their LPTs for the underlying assets.
- **requestPayout**: Exclusively for the `TradePair` contract to request a payout from the pool.
- **setMaxBorrowRate**: Sets the maximum hourly borrow rate.
- **totalAssets**: Returns the total assets in the liquidity pool.
- **ratio**: Calculates the ratio of total supply to total assets.

#### View Functions

- **previewDeposit**: Gives a preview of how many LPTs will be received for a given amount of deposited assets.
- **previewRedeem**: Provides a preview of the amount of assets that can be redeemed for a given number of LPTs.

#### Events

- **Deposit**: Triggered when a user deposits assets into the liquidity pool.
- **Redeem**: Triggered when a user redeems LPTs for assets.
- **MaxBorrowRateSet**: Triggered when the maximum borrow rate is set or modified.

#### Modifiers

- **onlyTradePair**: Ensures that only the associated `TradePair` contract can call certain functions.

#### Internal Functions

- **\_updateFeeIntegrals**: Updates the accumulated fee integrals in the `TradePair` contract.

### PriceFeed Contract

`PriceFeed` provides an interface between the Peppy Finance ecosystem and the Pyth oracle system to retrieve asset prices. The prices obtained from Pyth are normalized to be consistent with the system's precision.

#### Key Features

- **Price Integration**: Integrates with the Pyth oracle system to fetch asset prices.
- **Price Normalization**: Adjusts the price fetched from Pyth to match the desired precision.
- **Dynamic Price Feed Setting**: Allows dynamic association of tokens to their corresponding price feed IDs.

#### Public Variables

- **pyth**: The Pyth oracle contract instance used to fetch asset prices.
- **PRICE_PRECISION**: Constant that defines the precision level for prices.
- **priceIds**: Mapping of token addresses to their respective Pyth price feed IDs.

#### Core Functions

- **setPriceFeed**: Associates a token address with a Pyth price feed ID.
- **getPrice**: Fetches and returns the normalized price of a given token.

#### Internal Functions

- **\_normalize**: Takes a price structure from Pyth and normalizes it to match the desired precision.
- **\_getPrice**: Retrieves the Pyth price for a given feed ID, updating the price feeds if necessary.

#### Events

_None explicitly defined in the provided contract._

#### Modifiers

_None explicitly defined in the provided contract._
