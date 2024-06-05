# Timeswap V2
Timeswap is a fixed time preference protocol for users to manage their ERC20 tokens over discrete time. It
works as a zero liquidation fixed maturity money market and options market in one. Users can lend tokens
into the pool to earn fixed yields. They can also borrow or leverage tokens against other tokens, without the
fear of liquidation. Liquidity providers (different from lenders) create markets for any pair of tokens, adding
liquidity, and being the counterparty to all lenders and borrowers of the protocol. In return, they earn
transaction fees from both sides of the market. Timeswap utilizes a unique constant sum options specification
and a duration weighted constant product automated market maker (AMM) similar to Uniswap AMM. It is
designed to not utilize oracles, is capital efficient, permissionless to deploy, game theoretically sound in any
state of the market, and is easy to use. It becomes the fundamental time preference primitive lego to build
exotic and interesting DeFi products that need discrete time preference.
## \***\*Smart Contracts in scope \*\***

## TAG : 2.6.1

- `v2-periphery-nodex/`
- `v2-periphery/ `
- `v2-option/ `
- `v2-pool/`
- `v2-library/`
- `v2-token/`


- A Timeswap pool uses the Duration Weighted Constant Product automated market maker (AMM) similar to Uniswap. It is designed specifically for pricing of Timeswap options.
  Let 𝑥 be the borrow position with token0 as collateral, Let y be the borrow position with token1 as collateral. Let 𝑧 be the lending position per second in the pool.
  Let 𝑑 be the duration of the pool, thus 𝑑𝑧 is the total number of lending positions in the pool.
  Let 𝐿 be the square root of the constant product of the AMM. (𝑘 = 𝐿2) Let 𝐼 be the marginal interest rate per second of the Short per total Long.
  (𝑥 + 𝑦)𝑧 =𝐿 (square)
- The token does not conform to ERC20 standard, it uses ERC1155 standard.
- Contracts inside `test/` subdirectory is not within scope
- As this is a monorepo, where remappings are required for compilation there might be [issues](https://github.com/crytic/crytic-compile/issues/279) when running slither
- [Link to Documentation](https://www.notion.so/Timeswap-v2-Product-Specification-e1514392ea294b06934f25c38a3d8ea5) (Note: this requires a notion account to view)
- [Link to whitepaper](https://github.com/code-423n4/2022-10-timeswap/blob/main/whitepaper.pdf)


## Compilation
Go into the respective package and run `forge compile` to compile

## Test
Go into the respective package and run `forge test` to run the tests

