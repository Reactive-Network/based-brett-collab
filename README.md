# Based Brett Reactive Leaderboard

## Deployment & Configuration

### Environment Variables

Assign the following configuration variables before deployment.

#### RPC URLs, PKs & Network Config

Set the following environment variables according to your setup and the respective network documentation:

* `SEPOLIA_RPC`
* `REACTIVE_RPC`
* `DEPLOYMENT_PK`: The private key for deployment. The current implementation assumes the same key is used across all networks for authorization.
* `CALLBACK_PROXY_ADDR`: The address of the callback proxy on the destination network (e.g., `0x3316559B70Ee698DBD07505800263639F76a19d8` for Sepolia).

#### Chain IDs & Brett Token Contract Address

For testing and development purposes, the current implementation supports deploying the leaderboard contract to a network different from the token contract. Note that in such cases, contract blacklisting will not function properly, as the oracle will query the contract code on the incorrect network.

Example configuration for Base as the origin chain and Ethereum Sepolia as the destination testnet:

```bash
export ORIGIN_CHAIN_ID=8453 # Base
export DESTINATION_CHAIN_ID=11155111 # Sepolia testnet
export BRETT_ADDR=0x532f27101965dd16442E59d40670FaF5eBB142E4
```

For testing with Brett pre-deployed on Sepolia::

```bash
export ORIGIN_CHAIN_ID=11155111
export DESTINATION_CHAIN_ID=11155111
export BRETT_ADDR=0x7f1353A4b4CFda63f5B1B0d4673b914b64C8E7a8
```

To deploy your own Brett token contract, clone the mainnet contract and adjust the hardcoded addresses according to your needs and deployment setup. Ensure you have a functional Uniswap V2 setup (a third-party setup will suffice). After deployment, execute the `removeLimits()` and `enableTrading()` functions to enable unrestricted testing.

### Deployment

#### Step 1 — Leaderboard Contract

First, deploy the leaderboard contract to destination network:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $DEPLOYMENT_PK src/tokens/TokenizedLeaderboard.sol:TokenizedLeaderboard --constructor-args "Tokenized Leaderboard" "LDBRD" 3 3 $CALLBACK_PROXY_ADDR
```

Assign the contract address to `LDBRD_ADDR`.

* The third and fourth constructor arguments specify the number of leaderboards and the number of positions per leaderboard, respectively. **These parameters can't be changed after deployment**.
* To fund the contract for callback execution, send funds during deployment using the `--value` flag or send a direct transfer:

```bash
cast send $LDBRD_ADDR --rpc-url $SEPOLIA_RPC --private-key $DEPLOYMENT_PK --value 0.1ether
```

#### Step 2 — Reactive Contract

Next, deploy the reactive contract(s):

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $DEPLOYMENT_PK src/reactive/MonotonicSingleMetricReactive.sol:MonotonicSingleMetricReactive --constructor-args $ORIGIN_CHAIN_ID $BRETT_ADDR $DESTINATION_CHAIN_ID $LDBRD_ADDR 3 0 0 100
```

The first four constructor arguments configure the network and contract interaction:

1. **ORIGIN_CHAIN_ID**: Chain ID of the origin network.
2. **BRETT_ADDR**: Address of the Brett token contract.
3. **DESTINATION_CHAIN_ID**: Chain ID of the destination network.
4. **LDBRD_ADDR**: Address of the leaderboard contract.

Additional constructor arguments are:

5. **Number of Positions on the Leaderboard**: Should match the parameter in the leaderboard contract.
6. **Metric Type**: Defines the metric to track (`0` for turnover, `1` for inflow).
7. **Metric Index**: A value between `0` and the total number of leaderboards (exclusive). **Do not reuse the same metric index for multiple reactive contracts, as this will break the leaderboard**.
8. **Block Tick**: Number of blocks between leaderboard updates. The leaderboard updates only if transfers occur within this range.

#### Optional Step — Pause & Resume

To pause the contract, call `pause()`:

```bash
cast send $REACTIVE_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $DEPLOYMENT_PK
```

To resume the contract, call `resume()`:

```bash
cast send $REACTIVE_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $DEPLOYMENT_PK
```
