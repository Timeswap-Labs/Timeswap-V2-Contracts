// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2PeripheryQuoterBorrowGivenPosition} from "@timeswap-labs/v2-periphery/contracts/interfaces/lens/ITimeswapV2PeripheryQuoterBorrowGivenPosition.sol";

import {TimeswapV2PeripheryNoDexQuoterBorrowGivenPositionParam} from "../../structs/lens/QuoterParam.sol";

import {IMulticall} from "../IMulticall.sol";

/// @title An interface for TS-V2 Periphery NoDex Borrow Given Position.
interface ITimeswapV2PeripheryNoDexQuoterBorrowGivenPosition is
  ITimeswapV2PeripheryQuoterBorrowGivenPosition,
  IMulticall
{
  /// @dev The borrow given position function.
  /// @param param Borrow given position param.
  /// @return tokenAmount
  function borrowGivenPosition(
    TimeswapV2PeripheryNoDexQuoterBorrowGivenPositionParam calldata param,
    uint96 durationForward
  ) external returns (uint256 tokenAmount, uint160 timeswapV2SqrtInterestRateAfter);
}
