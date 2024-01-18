# Euphrates
contracts for LST staking of Acala

## Deployed Contract

| Contract Name | Contract Address | Code Verify |
| --- | --- | --- |
| WrappedTDOT | 0xe1bD4306A178f86a9214c39ABCD53D021bEDb0f9 | [blockscout](https://blockscout.acala.network/address/0xe1bD4306A178f86a9214c39ABCD53D021bEDb0f9/contracts#address-tabs) |
| ProxyAdmin | 0x3F86533602Cae17d10173269ecB6Efce1d68D5ec | [blockscout](https://blockscout.acala.network/address/0x3F86533602Cae17d10173269ecB6Efce1d68D5ec/contracts#address-tabs) |
| TransparentUpgradeableProxy | 0x7Fe92EC600F15cD25253b421bc151c51b0276b7D | [blockscout](https://blockscout.acala.network/address/0x7Fe92EC600F15cD25253b421bc151c51b0276b7D/contracts#address-tabs) |
| UpgradeableStakingLST (v1 implemention) | 0xBe44E43fE3817629d0cfA8CC0b73101d0F0FDE56 | [blockscout](https://blockscout.acala.network/address/0xBe44E43fE3817629d0cfA8CC0b73101d0F0FDE56/contracts#address-tabs) |
| UpgradeableStakingLSTV2 (v2 implemention) | 0xfa68ce20228ae14ac338aedb95f0f55b4e8b2bbe | [blockscout](https://blockscout.acala.network/address/0xfa68ce20228ae14ac338aedb95f0f55b4e8b2bbe/contracts#address-tabs) |
| DOT2WTDOTConvertor | 0x308b5fe2f06cc03916fe3a969caf7174ba32ad90 | [blockscout](https://blockscout.acala.network/address/0x308b5fe2f06cc03916fe3a969caf7174ba32ad90/contracts#address-tabs) |
| DOT2LDOTConvertor | 0x7f850ed2de2d4919050bdeda492a41432c42a39c | [blockscout](https://blockscout.acala.network/address/0x7f850ed2de2d4919050bdeda492a41432c42a39c/contracts#address-tabs) |
| LCDOT2WTDOTConvertor | 0x687b4240581b1baddd1cb317831a6846cf028272 | [blockscout](https://blockscout.acala.network/address/0x687b4240581b1baddd1cb317831a6846cf028272/contracts#address-tabs) |
| LCDOT2LDOTConvertor | 0xf2d1c488b2b5131d820984f190fc0866dea2bd78 | [blockscout](https://blockscout.acala.network/address/0xf2d1c488b2b5131d820984f190fc0866dea2bd78/contracts#address-tabs) |
| LendingPoolDepositConvertor(DOT) | 0xba05012265db9b3a5b516b635a5ffb0d27e9384f | [blockscout](https://blockscout.acala.network/address/0xba05012265db9b3a5b516b635a5ffb0d27e9384f/contracts#address-tabs) |
| LendingPoolDepositConvertor(LDOT) | 0xf31a85a7e2d784fdf2122b13dfee47911a6de4d1 | [blockscout](https://blockscout.acala.network/address/0xf31a85a7e2d784fdf2122b13dfee47911a6de4d1/contracts#address-tabs) |
| WrappedTUSD | 0xe8241c59abfac0168637e3a8749c44a9d64291d3 | [blockscout](https://blockscout.acala.network/address/0xe8241c59abfac0168637e3a8749c44a9d64291d3/contracts#address-tabs) |
| StableAssetStakeUtil | 0xc9a90cb6a2fc63babc93f08ea30b1c056f66461d | [blockscout](https://blockscout.acala.network/address/0xc9a90cb6a2fc63babc93f08ea30b1c056f66461d/contracts#address-tabs) |

## Prerequisites
install foundry:  
```
# clone the repository
git clone https://github.com/foundry-rs/foundry.git
cd foundry
# install Forge + Cast
cargo install --path ./cli --profile local --bins --force
# install Anvil
cargo install --path ./anvil --profile local --force
# install Chisel
cargo install --path ./chisel --profile local --force
```

## forge build
`forge build` to build project and generate ABI

## forge test
`forge test -vvvv` to run unit tests

## deployment
Can use `forge create` to deploy contract, that's simple but has some some limitations, you can refer to the [forge create documentation](https://book.getfoundry.sh/reference/forge/forge-create)
Alternatively, use `forge script` to run the deployment scripts.

## Bug Bounty Program

Please submit all the security issues to our [Bug Bounty Program](https://immunefi.com/bounty/euphrates/).
