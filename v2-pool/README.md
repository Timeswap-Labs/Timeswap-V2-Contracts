# Timeswap `v2-pool`
Implementation of pool logic of Timeswap V2 Protocol.

## Compilation
This repository supports compilation via `hardhat` and `forge`. The latter being used for testing while the former being used for better deployment support.

### Hardhat approach
Run `npx hardhat compile` or `yarn hardhat compile` while your shell is in this directory

### Forge approach
Make sure `forge` is installed, if not follow these steps.

`curl -L https://foundry.paradigm.xyz | bash`

This will install `foundryup`, a command to install and upgrade `foundry`. So run `foundryup`

`forge compile` will compile all the smart contracts to `out` directory in `v2-option` directory itself.

Afterwards fun `forge test` at `v2-option` directory, tests from this folder will automatically be detected and run. For more information related to test, check out `README.md` at `test/`


## Notes
- The contracts like most others roundUp/roundDown calculations, which may account for some minor loss from rounding. Eg: When minting using givenTokensAndLong and burning using givenTokensAndLong using given, the total short that one can burn might be 1 less than the actual short position owned. This maybe mitigated by using the same library as the one pool uses while calculating the long amount required for the short position amount.
- It is recommended to call initialise and mint for the initial liquidity addition in a single multicall as otherwise it is possible for a malicious actor to sandwhich the transactions.