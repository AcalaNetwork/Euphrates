# Euphrates
contracts for LST staking of Acala

## Deployed Contract

| Contract Name | Contract Address | Code Verify |
| --- | --- | --- |
| WrappedTDOT | 0xe1bD4306A178f86a9214c39ABCD53D021bEDb0f9 | [blockscout](https://blockscout.acala.network/address/0xe1bD4306A178f86a9214c39ABCD53D021bEDb0f9/contracts#address-tabs) |
| ProxyAdmin | 0x3F86533602Cae17d10173269ecB6Efce1d68D5ec | [blockscout](https://blockscout.acala.network/address/0x3F86533602Cae17d10173269ecB6Efce1d68D5ec/contracts#address-tabs) |
| TransparentUpgradeableProxy | 0x7Fe92EC600F15cD25253b421bc151c51b0276b7D | [blockscout](https://blockscout.acala.network/address/0x7Fe92EC600F15cD25253b421bc151c51b0276b7D/contracts#address-tabs) |
| UpgradeableStakingLST | 0xBe44E43fE3817629d0cfA8CC0b73101d0F0FDE56 | [blockscout](https://blockscout.acala.network/address/0xBe44E43fE3817629d0cfA8CC0b73101d0F0FDE56/contracts#address-tabs) |

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
