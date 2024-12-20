# Based Brett Reactive Leaderboard

## Deployment & Configuration

### Environment Variables

Assign the following configuration variables before deployment.

#### RPC URLs, PKs & Network Config

Set the following environment variables according to your setup and the respective network documentation:

* `REGISTRATION_RPC`
* `LEADRBOARD_RPC`
* `REACTIVE_RPC`
* `TOKEN_CHAIN_ID`
* `REGISTRATION_CHAIN_ID`
* `LEADERBOARD_CHAIN_ID`
* `DEPLOYMENT_PK`: The private key for deployment. The current implementation assumes the same key is used across for the leaderboard contract and the reactive component. The registration contract may use a different key.
* `LEADERBOARD_CALLBACK_PROXY_ADDR`: The address of the callback proxy on the leaderboard network (e.g., `0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8` for Sepolia).
* `BRETT_ADDR`
* `COUNTERPARTY_ADDR_1`
* `COUNTERPARTY_ADDR_2`
* `START_BLOCK`
* `END_BLOCK`
* `NUM_TOP`
* `BLOCK_TICK`

Chain IDs should match the RPC providers. Relevant chain IDs:

* Base: `8453`
* Sepolia: `11155111`
* Rective Network: `5318008`

Live Brett is deployed at `0x532f27101965dd16442E59d40670FaF5eBB142E4`. Slightly customized test Brett deployed on Sepolia can be found at `0x7f1353A4b4CFda63f5B1B0d4673b914b64C8E7a8`. WETH suitable for testing is deployed on RN at `0xF09bAc493de46a1AE331e678F9a1a7D69f3FfF23`.

Use `0xFe5A45dB052489cbc16d882404bcFa4f6223A55E` and `0x2C15e8021857ca44502045D27e2A866Ffd4cAEac` as counterparties on RN.

A couple of WETH/BRETT pairs on Base: `0x404E927b203375779a6aBD52A2049cE0ADf6609B`, `0xba3f945812a83471d709bce9c3ca699a19fb46f7`.

To deploy your own Brett token contract, clone the mainnet contract and adjust the hardcoded addresses according to your needs and deployment setup. Ensure you have a functional Uniswap V2 setup (a third-party setup will suffice). After deployment, execute the `removeLimits()` and `enableTrading()` functions to enable unrestricted testing.

### Deployment

First deploy the registration contract:

```bash
forge create --rpc-url $REGISTRATION_RPC --private-key $DEPLOYMENT_PK src/contracts/BasedBrettChallenge.sol:BasedBrettChallenge --constructor-args $START_BLOCK $END_BLOCK
```

Assign the contract address to `REG_ADDR`.

Now deploy the leaderboard contract:

```bash
forge create --rpc-url $LEADERBOARD_RPC --private-key $DEPLOYMENT_PK src/tokens/TokenizedLeaderboard.sol:TokenizedLeaderboard --value 10ether --constructor-args $LEADERBOARD_CALLBACK_PROXY_ADDR $NUM_TOP
```

Assign the contract address to `LDBRD_ADDR`.

Next, deploy the reactive contract:

```bash
forge create --rpc-url $REACTIVE_RPC --private-key $DEPLOYMENT_PK src/reactive/MonotonicSingleMetricReactive.sol:MonotonicSingleMetricReactive --value 10ether --constructor-args "($TOKEN_CHAIN_ID,$BRETT_ADDR,$REGISTRATION_CHAIN_ID,$REG_ADDR,$LEADERBOARD_CHAIN_ID,$LDBRD_ADDR,$NUM_TOP,0,$BLOCK_TICK,$START_BLOCK,$END_BLOCK,[$COUNTERPARTY_ADDR_1,$COUNTERPARTY_ADDR_2])"
```

Assign the contract address to `BRRCT_ADDR`.

#### Optional Step — Pause & Resume

To pause the contract, call `pause()`:

```bash
cast send $BRRCT_ADDR "pause()" --rpc-url $REACTIVE_RPC --private-key $DEPLOYMENT_PK
```

To resume the contract, call `resume()`:

```bash
cast send $BRRCT_ADDR "resume()" --rpc-url $REACTIVE_RPC --private-key $DEPLOYMENT_PK
```

## Test Deployments

All-RN with WETH:

```
export BRETT_ADDR=0xF09bAc493de46a1AE331e678F9a1a7D69f3FfF23
export REG_ADDR=0xC2E56cDb85116F75F2E2A4483bCeF07cD2d77BE0
export LDBRD_ADDR=0x97203d3414D6C1bC5a6661c8b7E70d16aC47D6ba
export BRRCT_ADDR=0x4a826bD7B3aDbD674C101b7B2eC7520edde5Eb65
```

All-RN with live Brett:

```
export BRETT_ADDR=0x532f27101965dd16442E59d40670FaF5eBB142E4
export REG_ADDR=0xC9D5707f3B41125a7db73FDC4AF6e642B9915eEc
export LDBRD_ADDR=0x301778111E596C21444e6A05A4C49887b46C4eBE
export BRRCT_ADDR=0xE3cdD8695da94cD11a42Cc91E792b15124C22b70
```
