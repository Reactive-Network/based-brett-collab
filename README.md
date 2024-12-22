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
* `COUNTERPARTY_ADDR_3`
* `COUNTERPARTY_ADDR_4`
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

A couple of WETH/BRETT pairs on Base: `0x404E927b203375779a6aBD52A2049cE0ADf6609B`, `0xba3f945812a83471d709bce9c3ca699a19fb46f7`. Routers are `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD` and `0xf2614A233c7C3e7f08b1F887Ba133a13f1eb2c55`.

To deploy your own Brett token contract, clone the mainnet contract and adjust the hardcoded addresses according to your needs and deployment setup. Ensure you have a functional Uniswap V2 setup (a third-party setup will suffice). After deployment, execute the `removeLimits()` and `enableTrading()` functions to enable unrestricted testing.

### Deployment

Live parameters:

```bash
export REGISTRATION_RPC="https://base.drpc.org"
export LEADRBOARD_RPC="https://base.drpc.org"
export REACTIVE_RPC="https://kopli-rpc.reactive.network/"
export TOKEN_CHAIN_ID=8453
export REGISTRATION_CHAIN_ID=8453
export LEADERBOARD_CHAIN_ID=8453
export LEADERBOARD_CALLBACK_PROXY_ADDR=0x4730c58FDA9d78f60c987039aEaB7d261aAd942E
export BRETT_ADDR=0x532f27101965dd16442E59d40670FaF5eBB142E4
export COUNTERPARTY_ADDR_1=0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD
export COUNTERPARTY_ADDR_2=0xf2614A233c7C3e7f08b1F887Ba133a13f1eb2c55
export COUNTERPARTY_ADDR_3=0x404E927b203375779a6aBD52A2049cE0ADf6609B
export COUNTERPARTY_ADDR_4=0xba3f945812a83471d709bce9c3ca699a19fb46f7
export START_BLOCK=24050526
export END_BLOCK=25389726
export NUM_TOP=60
export BLOCK_TICK=21600
```

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
forge create --legacy --rpc-url $REACTIVE_RPC --private-key $DEPLOYMENT_PK src/reactive/MonotonicSingleMetricReactive.sol:MonotonicSingleMetricReactive --value 10ether --constructor-args "($TOKEN_CHAIN_ID,$BRETT_ADDR,$REGISTRATION_CHAIN_ID,$REG_ADDR,$LEADERBOARD_CHAIN_ID,$LDBRD_ADDR,$NUM_TOP,0,$BLOCK_TICK,$START_BLOCK,$END_BLOCK,[$COUNTERPARTY_ADDR_1,$COUNTERPARTY_ADDR_2,$COUNTERPARTY_ADDR_3,$COUNTERPARTY_ADDR_4])"
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
export REG_ADDR=0x16f452638C64256a39c733B816A614602F6db424
export LDBRD_ADDR=0x04Ae2a17C0CeD148Dd9FcE8dF76327B330492907
export BRRCT_ADDR=0x65C36096b634EbB45DD924e91E2854c430E6dB49
```

All-RN with live Brett:

```
export BRETT_ADDR=0x532f27101965dd16442E59d40670FaF5eBB142E4
export REG_ADDR=0x5e70b2eBD16B75060A606ee6c0be200e884089A8
export LDBRD_ADDR=0x0d46D37c85541672f08bA1874ff904D4493a198a
export BRRCT_ADDR=0x448ab2f4f25e57a1463fcC73d0E0D39ad544D55c
```
