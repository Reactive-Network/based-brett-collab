#

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/Contract.sol:BrettToken --constructor-args "[0xAfEfa3FeC75598E868b8527231Db8c431E51c2AE, 0xFe5A45dB052489cbc16d882404bcFa4f6223A55E]"
```

```
#export BRETT_ADDR=0x532f27101965dd16442E59d40670FaF5eBB142E4
export BRETT_ADDR=0x7f1353A4b4CFda63f5B1B0d4673b914b64C8E7a8
```

```
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $BRETT_ADDR "removeLimits()"
cast send --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY $BRETT_ADDR "enableTrading()"
```

```
forge create --rpc-url $SEPOLIA_RPC --private-key $SEPOLIA_PRIVATE_KEY src/tokens/TokenizedLeaderboard.sol:TokenizedLeaderboard
```

```
#export LDRBD_ADDR=0x536972D94033C73a1Ff87cd0B063D564C627753A
export LDRBD_ADDR=0xbbF42bB3D4B2290bAfBC5c1F79c522149864b14c
```

```
forge create --rpc-url $REACTIVE_RPC --private-key $SEPOLIA_PRIVATE_KEY src/reactive/MultimetricsReactive.sol:MultimetricsReactive --constructor-args $BRETT_ADDR $LDRBD_ADDR
```

```
#export BBRCT_ADDR=0xa803946F334D6A34DbED19A5f91C75dA0B8C83Ba
export BBRCT_ADDR=0x97203d3414D6C1bC5a6661c8b7E70d16aC47D6ba
```
