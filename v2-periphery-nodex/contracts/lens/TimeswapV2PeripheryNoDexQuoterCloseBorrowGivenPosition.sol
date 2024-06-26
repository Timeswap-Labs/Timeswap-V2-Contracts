// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenPosition} from "@timeswap-labs/v2-token/contracts/structs/Position.sol";

import {TimeswapV2PeripheryQuoterCloseBorrowGivenPosition} from "@timeswap-labs/v2-periphery/contracts/lens/TimeswapV2PeripheryQuoterCloseBorrowGivenPosition.sol";

import {TimeswapV2PeripheryCloseBorrowGivenPositionParam} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";
import {TimeswapV2PeripheryCloseBorrowGivenPositionChoiceInternalParam, TimeswapV2PeripheryCloseBorrowGivenPositionInternalParam} from "@timeswap-labs/v2-periphery/contracts/structs/InternalParam.sol";

import {ITimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPosition} from "../interfaces/lens/ITimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPosition.sol";

import {TimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPositionParam} from "../structs/lens/QuoterParam.sol";

import {OnlyOperatorReceiver} from "../base/OnlyOperatorReceiver.sol";
import {Multicall} from "../base/Multicall.sol";

contract TimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPosition is
  ITimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPosition,
  TimeswapV2PeripheryQuoterCloseBorrowGivenPosition,
  OnlyOperatorReceiver,
  Multicall
{
  constructor(
    address chosenOptionFactory,
    address chosenPoolFactory,
    address chosenTokens
  ) TimeswapV2PeripheryQuoterCloseBorrowGivenPosition(chosenOptionFactory, chosenPoolFactory, chosenTokens) {}

  function closeBorrowGivenPosition(
    TimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPositionParam calldata param,
    uint96 durationForward
  ) external returns (uint256 tokenAmount, uint160 timeswapV2SqrtInterestRateAfter) {
    bytes memory data = abi.encode(param.isToken0);

    (, , data, timeswapV2SqrtInterestRateAfter) = closeBorrowGivenPosition(
      TimeswapV2PeripheryCloseBorrowGivenPositionParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        to: (param.isToken0 == param.isLong0) ? address(this) : param.to,
        isLong0: param.isLong0,
        positionAmount: param.positionAmount,
        data: data
      }),
      durationForward
    );

    tokenAmount = abi.decode(data, (uint256));
  }

  function timeswapV2PeripheryCloseBorrowGivenPositionChoiceInternal(
    TimeswapV2PeripheryCloseBorrowGivenPositionChoiceInternalParam memory param
  ) internal pure override returns (uint256 token0Amount, uint256 token1Amount, bytes memory data) {
    bool isToken0 = abi.decode(param.data, (bool));

    uint256 tokenAmount = StrikeConversion.turn(param.tokenAmount, param.strike, !isToken0, true);

    token0Amount = isToken0 ? tokenAmount : 0;
    token1Amount = isToken0 ? 0 : tokenAmount;

    data = param.data;
  }

  function timeswapV2PeripheryCloseBorrowGivenPositionInternal(
    TimeswapV2PeripheryCloseBorrowGivenPositionInternalParam memory param
  ) internal pure override returns (bytes memory data) {
    bool isToken0 = abi.decode(param.data, (bool));

    data = abi.encode(isToken0 ? param.token0Amount : param.token1Amount);
  }
}
