// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";
import {Error} from "@timeswap-labs/v2-library/contracts/Error.sol";

import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";

import {TimeswapV2PeripheryQuoterBorrowGivenPrincipal} from "@timeswap-labs/v2-periphery/contracts/lens/TimeswapV2PeripheryQuoterBorrowGivenPrincipal.sol";

import {TimeswapV2PeripheryBorrowGivenPrincipalParam} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";
import {TimeswapV2PeripheryBorrowGivenPrincipalInternalParam} from "@timeswap-labs/v2-periphery/contracts/structs/InternalParam.sol";

import {ITimeswapV2PeripheryNoDexQuoterBorrowGivenPrincipal} from "../interfaces/lens/ITimeswapV2PeripheryNoDexQuoterBorrowGivenPrincipal.sol";

import {TimeswapV2PeripheryNoDexQuoterBorrowGivenPrincipalParam} from "../structs/lens/QuoterParam.sol";

import {Multicall} from "../base/Multicall.sol";

contract TimeswapV2PeripheryNoDexQuoterBorrowGivenPrincipal is
  ITimeswapV2PeripheryNoDexQuoterBorrowGivenPrincipal,
  TimeswapV2PeripheryQuoterBorrowGivenPrincipal,
  Multicall
{
  constructor(
    address chosenOptionFactory,
    address chosenPoolFactory,
    address chosenTokens
  ) TimeswapV2PeripheryQuoterBorrowGivenPrincipal(chosenOptionFactory, chosenPoolFactory, chosenTokens) {}

  function borrowGivenPrincipal(
    TimeswapV2PeripheryNoDexQuoterBorrowGivenPrincipalParam calldata param,
    uint96 durationForward
  ) external returns (uint256 positionAmount, uint160 timeswapV2SqrtInterestRateAfter) {
    (, address poolPair) = PoolFactoryLibrary.getWithCheck(optionFactory, poolFactory, param.token0, param.token1);

    (uint256 token0Balance, uint256 token1Balance) = ITimeswapV2Pool(poolPair).totalLongBalanceAdjustFees(
      param.strike,
      param.maturity
    );

    if (param.isToken0) Error.checkEnough(token0Balance, param.tokenAmount);
    else Error.checkEnough(token1Balance, param.tokenAmount);
    bytes memory data = abi.encode(msg.sender, param.tokenTo, param.isToken0);

    (positionAmount, , timeswapV2SqrtInterestRateAfter) = borrowGivenPrincipal(
      TimeswapV2PeripheryBorrowGivenPrincipalParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        tokenTo: param.isToken0 == param.isLong0 ? address(this) : param.tokenTo,
        longTo: param.longTo,
        isLong0: param.isLong0,
        token0Amount: param.isToken0 ? param.tokenAmount : 0,
        token1Amount: param.isToken0 ? 0 : param.tokenAmount,
        data: data
      }),
      durationForward
    );
  }

  function timeswapV2PeripheryBorrowGivenPrincipalInternal(
    TimeswapV2PeripheryBorrowGivenPrincipalInternalParam memory param
  ) internal override returns (bytes memory data) {}
}
