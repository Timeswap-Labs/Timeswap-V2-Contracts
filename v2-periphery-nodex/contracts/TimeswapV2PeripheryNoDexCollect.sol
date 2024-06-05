// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {Error} from "@timeswap-labs/v2-library/contracts/Error.sol";

import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {ITimeswapV2LiquidityToken} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2LiquidityToken.sol";

import {TimeswapV2TokenPosition, TimeswapV2LiquidityTokenPosition} from "@timeswap-labs/v2-token/contracts/structs/Position.sol";

import {TimeswapV2PeripheryCollect} from "@timeswap-labs/v2-periphery/contracts/TimeswapV2PeripheryCollect.sol";

import {TimeswapV2PeripheryCollectParam} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";

import {ITimeswapV2PeripheryNoDexCollect} from "./interfaces/ITimeswapV2PeripheryNoDexCollect.sol";

import {TimeswapV2PeripheryNoDexCollectParam} from "./structs/Param.sol";

import {OnlyOperatorReceiver} from "./base/OnlyOperatorReceiver.sol";
import {NativeImmutableState, NativeWithdraws} from "./base/Native.sol";
import {Multicall} from "./base/Multicall.sol";

/// @author Timeswap Labs
contract TimeswapV2PeripheryNoDexCollect is
  TimeswapV2PeripheryCollect,
  ITimeswapV2PeripheryNoDexCollect,
  OnlyOperatorReceiver,
  NativeImmutableState,
  NativeWithdraws,
  Multicall
{
  constructor(
    address chosenOptionFactory,
    address chosenTokens,
    address chosenLiquidityTokens,
    address chosenNative
  )
    TimeswapV2PeripheryCollect(chosenOptionFactory, chosenTokens, chosenLiquidityTokens)
    NativeImmutableState(chosenNative)
  {}

  function collect(
    TimeswapV2PeripheryNoDexCollectParam calldata param
  ) external returns (uint256 token0Amount, uint256 token1Amount) {
    if (param.deadline < block.timestamp) Error.deadlineReached(param.deadline);

    ITimeswapV2Token(tokens).transferTokenPositionFrom(
      msg.sender,
      address(this),
      TimeswapV2TokenPosition({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        position: TimeswapV2OptionPosition.Short
      }),
      param.excessShortAmount
    );

    (, , uint256 shortFees, uint256 shortReturned) = ITimeswapV2LiquidityToken(liquidityTokens)
      .feesEarnedAndShortReturnedOf(
        msg.sender,
        TimeswapV2LiquidityTokenPosition({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity
        })
      );

    (token0Amount, token1Amount, , ) = collect(
      TimeswapV2PeripheryCollectParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        token0To: param.to,
        token1To: param.to,
        excessShortAmount: param.excessShortAmount
      })
    );

    if (token0Amount < param.minToken0Amount) revert MinTokenReached(token0Amount, param.minToken0Amount);
    if (token1Amount < param.minToken1Amount) revert MinTokenReached(token1Amount, param.minToken1Amount);

    emit Collect(
      param.token0,
      param.token1,
      param.strike,
      param.maturity,
      param.to,
      token0Amount,
      token1Amount,
      shortFees,
      shortReturned,
      param.excessShortAmount
    );
  }
}
