// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {Verify} from "../../libraries/Verify.sol";

contract VerifyTest {
  function timeswapV2Option(address optionFactory, address token0, address token1) external view {
    Verify.timeswapV2Option(optionFactory, token0, token1);
  }

  function timeswapV2Pool(
    address optionFactory,
    address poolFactory,
    address token0,
    address token1
  ) external view returns (address optionPair) {
    return Verify.timeswapV2Pool(optionFactory, poolFactory, token0, token1);
  }

  function timeswapV2Token(address tokens) external view {
    Verify.timeswapV2Token(tokens);
  }

  function timeswapV2LiquidityToken(address liquidityTokens) external view {
    Verify.timeswapV2LiquidityToken(liquidityTokens);
  }
}
