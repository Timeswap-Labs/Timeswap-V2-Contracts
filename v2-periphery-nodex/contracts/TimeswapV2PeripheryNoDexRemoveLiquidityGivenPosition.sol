// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {Math} from "@timeswap-labs/v2-library/contracts/Math.sol";
import {Error} from "@timeswap-labs/v2-library/contracts/Error.sol";
import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";
import {ITimeswapV2LiquidityToken} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2LiquidityToken.sol";

import {TimeswapV2TokenPosition, TimeswapV2LiquidityTokenPosition} from "@timeswap-labs/v2-token/contracts/structs/Position.sol";

import {TimeswapV2PeripheryRemoveLiquidityGivenPosition} from "@timeswap-labs/v2-periphery/contracts/TimeswapV2PeripheryRemoveLiquidityGivenPosition.sol";

import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";

import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {TimeswapV2PeripheryRemoveLiquidityGivenPositionParam, FeesAndReturnedDelta, ExcessDelta} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";
import {TimeswapV2PeripheryRemoveLiquidityGivenPositionChoiceInternalParam, TimeswapV2PeripheryRemoveLiquidityGivenPositionNoBurnChoiceInternalParam, TimeswapV2PeripheryRemoveLiquidityGivenPositionTransferInternalParam} from "@timeswap-labs/v2-periphery/contracts/structs/InternalParam.sol";

import {ITimeswapV2PeripheryNoDexRemoveLiquidityGivenPosition} from "./interfaces/ITimeswapV2PeripheryNoDexRemoveLiquidityGivenPosition.sol";

import {TimeswapV2PeripheryNoDexRemoveLiquidityGivenPositionParam} from "./structs/Param.sol";

import {OnlyOperatorReceiver} from "./base/OnlyOperatorReceiver.sol";
import {NativeImmutableState, NativeWithdraws} from "./base/Native.sol";
import {Multicall} from "./base/Multicall.sol";

/// @title Capable of removing liquidity from the Timeswap V2 protocol given a Timeswap V2 Position
/// @author Timeswap Labs
contract TimeswapV2PeripheryNoDexRemoveLiquidityGivenPosition is
  ITimeswapV2PeripheryNoDexRemoveLiquidityGivenPosition,
  TimeswapV2PeripheryRemoveLiquidityGivenPosition,
  OnlyOperatorReceiver,
  NativeImmutableState,
  NativeWithdraws,
  Multicall
{
  using Math for uint256;

  constructor(
    address chosenOptionFactory,
    address chosenPoolFactory,
    address chosenTokens,
    address chosenLiquidityTokens,
    address chosenNative
  )
    TimeswapV2PeripheryRemoveLiquidityGivenPosition(
      chosenOptionFactory,
      chosenPoolFactory,
      chosenTokens,
      chosenLiquidityTokens
    )
    NativeImmutableState(chosenNative)
  {}

  function removeLiquidityGivenPosition(
    TimeswapV2PeripheryNoDexRemoveLiquidityGivenPositionParam calldata param
  )
    external
    returns (
      uint256 token0Amount,
      uint256 token1Amount,
      FeesAndReturnedDelta memory feesAndReturnedDelta,
      ExcessDelta memory excessDelta
    )
  {
    if (param.deadline < block.timestamp) Error.deadlineReached(param.deadline);

    {
      (, address poolPair) = PoolFactoryLibrary.getWithCheck(optionFactory, poolFactory, param.token0, param.token1);

      uint160 sqrtInterestRate = ITimeswapV2Pool(poolPair).sqrtInterestRate(param.strike, param.maturity);

      if (sqrtInterestRate < param.minSqrtInterestRate)
        revert MinSqrtInterestRateReached(sqrtInterestRate, param.minSqrtInterestRate);
      if (sqrtInterestRate > param.maxSqrtInterestRate)
        revert MaxSqrtInterestRateReached(sqrtInterestRate, param.maxSqrtInterestRate);

      if (param.liquidityAmount != 0)
        ITimeswapV2LiquidityToken(liquidityTokens).transferTokenPositionFrom(
          msg.sender,
          address(this),
          TimeswapV2LiquidityTokenPosition({
            token0: param.token0,
            token1: param.token1,
            strike: param.strike,
            maturity: param.maturity
          }),
          param.liquidityAmount,
          bytes("")
        );

      bytes memory data = abi.encode(msg.sender, param.isToken0);

      (token0Amount, token1Amount, feesAndReturnedDelta, excessDelta, ) = removeLiquidityGivenPosition(
        TimeswapV2PeripheryRemoveLiquidityGivenPositionParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          token0To: param.tokenTo,
          token1To: param.tokenTo,
          liquidityAmount: param.liquidityAmount,
          excessLong0Amount: param.excessLong0Amount,
          excessLong1Amount: param.excessLong1Amount,
          excessShortAmount: param.excessShortAmount,
          data: data
        })
      );
    }

    if (token0Amount < param.minToken0Amount) revert MinTokenReached(token0Amount, param.minToken0Amount);
    if (token1Amount < param.minToken1Amount) revert MinTokenReached(token1Amount, param.minToken1Amount);

    emit RemoveLiquidityGivenPosition(
      param.token0,
      param.token1,
      param.strike,
      param.maturity,
      msg.sender,
      param.tokenTo,
      token0Amount,
      token1Amount,
      param.liquidityAmount,
      feesAndReturnedDelta,
      excessDelta
    );
  }

  function timeswapV2PeripheryRemoveLiquidityGivenPositionChoiceInternal(
    TimeswapV2PeripheryRemoveLiquidityGivenPositionChoiceInternalParam memory param
  )
    internal
    pure
    override
    returns (
      uint256 token0AmountFromPool,
      uint256 token1AmountFromPool,
      uint256 token0AmountWithdraw,
      uint256 token1AmountWithdraw,
      bytes memory data
    )
  {
    (address msgSender, bool isToken0) = abi.decode(param.data, (address, bool));

    {
      uint256 token0Balance = param.token0Balance.min(
        StrikeConversion.turn(param.tokenAmountFromPool, param.strike, false, false)
      ) + param.excessToken0Amount;
      uint256 token1Balance = param.token1Balance.min(
        StrikeConversion.turn(param.tokenAmountFromPool, param.strike, true, false)
      ) + param.excessToken1Amount;

      uint256 tokenAmountWithdrawPreferred = StrikeConversion
        .turn(param.tokenAmountWithdraw, param.strike, !isToken0, false)
        .min(isToken0 ? token0Balance : token1Balance);

      uint256 tokenAmountWithdrawNotPreferred = StrikeConversion.dif(
        param.tokenAmountWithdraw,
        tokenAmountWithdrawPreferred,
        param.strike,
        isToken0,
        false
      );
      tokenAmountWithdrawNotPreferred = tokenAmountWithdrawNotPreferred.min(isToken0 ? token1Balance : token0Balance);

      token0AmountWithdraw = isToken0 ? tokenAmountWithdrawPreferred : tokenAmountWithdrawNotPreferred;
      token1AmountWithdraw = isToken0 ? tokenAmountWithdrawNotPreferred : tokenAmountWithdrawPreferred;
    }

    {
      uint256 tokenAmountFromPoolPreferred = StrikeConversion
        .turn(param.tokenAmountFromPool, param.strike, !isToken0, false)
        .min(isToken0 ? param.token0Balance : param.token1Balance);

      uint256 tokenAmountFromPoolNotPreferred = StrikeConversion.dif(
        param.tokenAmountFromPool,
        tokenAmountFromPoolPreferred,
        param.strike,
        isToken0,
        false
      );

      token0AmountFromPool = isToken0 ? tokenAmountFromPoolPreferred : tokenAmountFromPoolNotPreferred;
      token1AmountFromPool = isToken0 ? tokenAmountFromPoolNotPreferred : tokenAmountFromPoolPreferred;
    }

    data = abi.encode(msgSender);
  }

  function timeswapV2PeripheryRemoveLiquidityGivenPositionNoBurnChoiceInternal(
    TimeswapV2PeripheryRemoveLiquidityGivenPositionNoBurnChoiceInternalParam memory param
  ) internal pure override returns (uint256 token0AmountWithdraw, uint256 token1AmountWithdraw, bytes memory data) {
    (address msgSender, bool isToken0) = abi.decode(param.data, (address, bool));

    uint256 longAmount = StrikeConversion.combine(
      param.excessToken0Amount,
      param.excessToken1Amount,
      param.strike,
      true
    );

    if (longAmount == param.tokenAmountWithdraw) {
      token0AmountWithdraw = param.excessToken0Amount;
      token1AmountWithdraw = param.excessToken1Amount;
    } else {
      uint256 tokenAmountWithdrawPreferred = StrikeConversion
        .turn(param.tokenAmountWithdraw, param.strike, !isToken0, false)
        .min(isToken0 ? param.excessToken0Amount : param.excessToken1Amount);

      uint256 tokenAmountWithdrawNotPreferred = StrikeConversion.dif(
        param.tokenAmountWithdraw,
        tokenAmountWithdrawPreferred,
        param.strike,
        isToken0,
        false
      );

      token0AmountWithdraw = isToken0 ? tokenAmountWithdrawPreferred : tokenAmountWithdrawNotPreferred;
      token1AmountWithdraw = isToken0 ? tokenAmountWithdrawNotPreferred : tokenAmountWithdrawPreferred;
    }

    data = abi.encode(msgSender);
  }

  function timeswapV2PeripheryRemoveLiquidityGivenPositionTransferInternal(
    TimeswapV2PeripheryRemoveLiquidityGivenPositionTransferInternalParam memory param
  ) internal override returns (bytes memory data) {
    address msgSender = abi.decode(param.data, (address));

    if (param.excessLong0Amount != 0)
      ITimeswapV2Token(tokens).transferTokenPositionFrom(
        msgSender,
        address(this),
        TimeswapV2TokenPosition({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          position: TimeswapV2OptionPosition.Long0
        }),
        param.excessLong0Amount
      );

    if (param.excessLong1Amount != 0)
      ITimeswapV2Token(tokens).transferTokenPositionFrom(
        msgSender,
        address(this),
        TimeswapV2TokenPosition({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          position: TimeswapV2OptionPosition.Long1
        }),
        param.excessLong1Amount
      );

    if (param.excessShortAmount != 0)
      ITimeswapV2Token(tokens).transferTokenPositionFrom(
        msgSender,
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

    data = "";
  }
}
