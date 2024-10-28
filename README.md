# Based Brett Reactive Leaderboard

## Deployment & Configuration

### Environment Variables

You will need to assign the following configuration variables first.

#### RPC URLs, PKs & General Network Config

Assign the following environment variables in accordance with your setup and respective network documentation:

* `SEPOLIA_RPC`
* `REACTIVE_RPC`
* `DEPLOYMENT_PK` (the private key for deployment, the current implementation assumes the same key on all the networks involved for authorization purposes)
* `CALLBACK_PROXY_ADDR` (for chosen destination network, e.g. `0x3316559B70Ee698DBD07505800263639F76a19d8` for Sepolia)

#### Chain IDs & Brett Token Contract Address

For testing and development purposes only, the current implementation support deployment of the leaderboard contract to a network different than that of the token contract. Note that when using this configuration, contract blackilisting will not function properly, as the oracle will query the contract code on the wrong network.

```
export ORIGIN_CHAIN_ID=8453 # Base
export DESTINATION_CHAIN_ID=11155111 # Sepolia testnet
export BRETT_ADDR=0x532f27101965dd16442E59d40670FaF5eBB142E4
```

For testing with pre-deployed Brett on Sepolia, use the following configuration:

```
export ORIGIN_CHAIN_ID=11155111
export DESTINATION_CHAIN_ID=11155111
export BRETT_ADDR=0x7f1353A4b4CFda63f5B1B0d4673b914b64C8E7a8
```

You can deploy your own copy of Brett by cloning the mainnet contract and changing the hardcoded addresses in accordance with your needs and deployment setup. You will need a working Uniswap V2 setup to deploy. Third party should do. Send `removeLimits()` and `enableTrading()` after deployment to test freely.

### Deployment

Deploy the leaderboard contract to destination network first:

```
forge create --rpc-url $SEPOLIA_RPC --private-key $DEPLOYMENT_PK src/tokens/TokenizedLeaderboard.sol:TokenizedLeaderboard --constructor-args "Tokenized Leaderboard" "LDBRD" 3 3 $CALLBACK_PROXY_ADDR
```

Assign the contract address to `LDBRD_ADDR`.

The third and fourth constructor arguments are, respectively, the number of leaderboards and the number of positions on each leaderboard. **IMPORTANT:** These cannot be changed after deployment.

Send some funds to the deployed contract to pay for callbacks. Its `constructor()` is marked as payable, so this can be done on deployment by using the `--value` flag.

Now deploy the reactive contract, or contracts:

```
forge create --rpc-url $REACTIVE_RPC --private-key $DEPLOYMENT_PK src/reactive/MonotonicSingleMetricReactive.sol:MonotonicSingleMetricReactive --constructor-args $ORIGIN_CHAIN_ID $BRETT_ADDR $DESTINATION_CHAIN_ID $LDBRD_ADDR 3 0 0 100
```

The contract can be paused by sending the `pause()` message, and unpaused by sending `resume()`.

The first four constructor arguments configure the network and contract that the reactive contract will interact with.

The rest are as follows.

#### Number Of Position On The Leaderboard

Should match the corresponding parameter of the leaderboard contract.

#### Metric Type

Two types of metrics are supported by the current implementation:

* `0` - turnover
* `1` - inflow

#### Metric Index

A number in the range between `0` and number of leaderboards configured for the leaderboard contract (exclusive). Reusing the same metric index for more than one reactive contract is not supported and will break the leaderboard.

#### Block Tick

Number of blocks between leaderboard updates. Leaderboard will not update if there are no transfers in the given block range.
