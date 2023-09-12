# Euphrates
contracts for LST staking of Acala

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
