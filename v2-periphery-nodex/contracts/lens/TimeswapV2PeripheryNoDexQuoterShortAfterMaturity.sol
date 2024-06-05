// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenPosition} from "@timeswap-labs/v2-token/contracts/structs/Position.sol";

import {TimeswapV2PeripheryQuoterShortAfterMaturity} from "@timeswap-labs/v2-periphery/contracts/lens/TimeswapV2PeripheryQuoterShortAfterMaturity.sol";

import {TimeswapV2PeripheryShortAfterMaturityParam} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";

import {ITimeswapV2PeripheryNoDexQuoterShortAfterMaturity} from "../interfaces/lens/ITimeswapV2PeripheryNoDexQuoterShortAfterMaturity.sol";

import {TimeswapV2PeripheryNoDexQuoterShortAfterMaturityParam} from "../structs/lens/QuoterParam.sol";

import {Multicall} from "../base/Multicall.sol";

contract TimeswapV2PeripheryNoDexQuoterShortAfterMaturity is
  TimeswapV2PeripheryQuoterShortAfterMaturity,
  ITimeswapV2PeripheryNoDexQuoterShortAfterMaturity,
  Multicall
{
  constructor(address chosenOptionFactory) TimeswapV2PeripheryQuoterShortAfterMaturity(chosenOptionFactory) {}

  function shortAfterMaturity(
    TimeswapV2PeripheryNoDexQuoterShortAfterMaturityParam calldata param
  ) external override returns (uint256 token0Amount, uint256 token1Amount) {
    (token0Amount, token1Amount) = shortAfterMaturity(
      TimeswapV2PeripheryShortAfterMaturityParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        token0To: param.to,
        token1To: param.to,
        positionAmount: param.positionAmount
      })
    );
  }
}
