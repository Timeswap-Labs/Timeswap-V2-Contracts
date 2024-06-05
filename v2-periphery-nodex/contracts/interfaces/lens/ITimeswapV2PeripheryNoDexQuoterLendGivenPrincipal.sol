// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2PeripheryQuoterLendGivenPrincipal} from "@timeswap-labs/v2-periphery/contracts/interfaces/lens/ITimeswapV2PeripheryQuoterLendGivenPrincipal.sol";

import {TimeswapV2PeripheryNoDexQuoterLendGivenPrincipalParam} from "../../structs/lens/QuoterParam.sol";

import {IMulticall} from "../IMulticall.sol";

interface ITimeswapV2PeripheryNoDexQuoterLendGivenPrincipal is
  ITimeswapV2PeripheryQuoterLendGivenPrincipal,
  IMulticall
{
  function lendGivenPrincipal(
    TimeswapV2PeripheryNoDexQuoterLendGivenPrincipalParam calldata param,
    uint96 durationForward
  ) external returns (uint256 positionAmount, uint160 timeswapV2SqrtInterestRateAfter);
}
