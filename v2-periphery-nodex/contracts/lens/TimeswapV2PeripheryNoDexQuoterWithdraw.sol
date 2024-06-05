// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenPosition} from "@timeswap-labs/v2-token/contracts/structs/Position.sol";

import {TimeswapV2PeripheryQuoterWithdraw} from "@timeswap-labs/v2-periphery/contracts/lens/TimeswapV2PeripheryQuoterWithdraw.sol";

import {TimeswapV2PeripheryWithdrawParam} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";

import {ITimeswapV2PeripheryNoDexQuoterWithdraw} from "../interfaces/lens/ITimeswapV2PeripheryNoDexQuoterWithdraw.sol";

import {TimeswapV2PeripheryNoDexQuoterWithdrawParam} from "../structs/lens/QuoterParam.sol";

import {OnlyOperatorReceiver} from "../base/OnlyOperatorReceiver.sol";

import {Multicall} from "../base/Multicall.sol";

contract TimeswapV2PeripheryNoDexQuoterWithdraw is
  TimeswapV2PeripheryQuoterWithdraw,
  ITimeswapV2PeripheryNoDexQuoterWithdraw,
  OnlyOperatorReceiver,
  Multicall
{
  constructor(
    address chosenOptionFactory,
    address chosenTokens
  ) TimeswapV2PeripheryQuoterWithdraw(chosenOptionFactory, chosenTokens) {}

  function withdraw(
    TimeswapV2PeripheryNoDexQuoterWithdrawParam calldata param
  ) external override returns (uint256 token0Amount, uint256 token1Amount) {
    (token0Amount, token1Amount) = withdraw(
      TimeswapV2PeripheryWithdrawParam({
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
