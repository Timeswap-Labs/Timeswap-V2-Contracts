// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";

import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {TimeswapV2PeripheryAddLiquidityGivenPrincipalParam} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";
import {TimeswapV2PeripheryAddLiquidityGivenPrincipalChoiceInternalParam, TimeswapV2PeripheryAddLiquidityGivenPrincipalInternalParam} from "@timeswap-labs/v2-periphery/contracts/structs/InternalParam.sol";

import {ITimeswapV2PeripheryNoDexQuoterAddLiquidityGivenPrincipal} from "../interfaces/lens/ITimeswapV2PeripheryNoDexQuoterAddLiquidityGivenPrincipal.sol";

import {TimeswapV2PeripheryQuoterAddLiquidityGivenPrincipal} from "@timeswap-labs/v2-periphery/contracts/lens/TimeswapV2PeripheryQuoterAddLiquidityGivenPrincipal.sol";

import {TimeswapV2PeripheryNoDexQuoterAddLiquidityGivenPrincipalParam} from "../structs/lens/QuoterParam.sol";

import {Multicall} from "../base/Multicall.sol";

/// @author Timeswap Labs
contract TimeswapV2PeripheryNoDexQuoterAddLiquidityGivenPrincipal is
  ITimeswapV2PeripheryNoDexQuoterAddLiquidityGivenPrincipal,
  TimeswapV2PeripheryQuoterAddLiquidityGivenPrincipal,
  Multicall
{
  constructor(
    address chosenOptionFactory,
    address chosenPoolFactory,
    address chosenTokens,
    address chosenLiquidityTokens
  )
    TimeswapV2PeripheryQuoterAddLiquidityGivenPrincipal(
      chosenOptionFactory,
      chosenPoolFactory,
      chosenTokens,
      chosenLiquidityTokens
    )
  {}

  ///  @inheritdoc ITimeswapV2PeripheryNoDexQuoterAddLiquidityGivenPrincipal
  function initialize(
    address token0,
    address token1,
    uint256 strike,
    uint256 maturity,
    uint160 rate
  ) external override {
    (, address poolPair) = PoolFactoryLibrary.getWithCheck(optionFactory, poolFactory, token0, token1);

    ITimeswapV2Pool(poolPair).initialize(strike, maturity, rate);
  }

  ///  @inheritdoc ITimeswapV2PeripheryNoDexQuoterAddLiquidityGivenPrincipal
  function addLiquidityGivenPrincipal(
    TimeswapV2PeripheryNoDexQuoterAddLiquidityGivenPrincipalParam calldata param,
    uint96 durationForward
  )
    external
    returns (
      uint160 liquidityAmount,
      uint256 excessLongAmount,
      uint256 excessShortAmount,
      uint160 timeswapV2LiquidityAfter
    )
  {
    bytes memory data = abi.encode(msg.sender, param.isToken0);

    uint256 excessLong0Amount;
    uint256 excessLong1Amount;
    (
      liquidityAmount,
      excessLong0Amount,
      excessLong1Amount,
      excessShortAmount,
      ,
      timeswapV2LiquidityAfter
    ) = addLiquidityGivenPrincipal(
      TimeswapV2PeripheryAddLiquidityGivenPrincipalParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        liquidityTo: param.liquidityTo,
        token0Amount: param.isToken0 ? param.tokenAmount : 0,
        token1Amount: param.isToken0 ? 0 : param.tokenAmount,
        data: data,
        erc1155Data: param.erc1155Data
      }),
      durationForward
    );

    excessLongAmount = param.isToken0 ? excessLong0Amount : excessLong1Amount;
  }

  function timeswapV2PeripheryAddLiquidityGivenPrincipalChoiceInternal(
    TimeswapV2PeripheryAddLiquidityGivenPrincipalChoiceInternalParam memory param
  ) internal pure override returns (uint256 token0Amount, uint256 token1Amount, bytes memory data) {
    (, bool isToken0) = abi.decode(param.data, (address, bool));

    uint256 tokenAmount = StrikeConversion.turn(param.tokenAmount, param.strike, !isToken0, true);

    token0Amount = isToken0 ? tokenAmount : 0;
    token1Amount = isToken0 ? 0 : tokenAmount;

    data = param.data;
  }

  function timeswapV2PeripheryAddLiquidityGivenPrincipalInternal(
    TimeswapV2PeripheryAddLiquidityGivenPrincipalInternalParam memory
  ) internal pure override returns (bytes memory data) {
    data = bytes("");
  }
}
