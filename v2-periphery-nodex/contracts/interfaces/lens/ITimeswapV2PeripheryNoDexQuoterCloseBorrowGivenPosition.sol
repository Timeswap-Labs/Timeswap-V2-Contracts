// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2PeripheryQuoterCloseBorrowGivenPosition} from "@timeswap-labs/v2-periphery/contracts/interfaces/lens/ITimeswapV2PeripheryQuoterCloseBorrowGivenPosition.sol";

import {TimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPositionParam} from "../../structs/lens/QuoterParam.sol";

import {IMulticall} from "../IMulticall.sol";

/// @title An interface for TS-v2 Periphery NoDex Close Borrow Given Position.
interface ITimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPosition is
  ITimeswapV2PeripheryQuoterCloseBorrowGivenPosition,
  IMulticall
{
  /// @dev The close borrow given position function.
  /// @param param Close borrow given position param.
  /// @return tokenAmount
  function closeBorrowGivenPosition(
    TimeswapV2PeripheryNoDexQuoterCloseBorrowGivenPositionParam calldata param,
    uint96 durationForward
  ) external returns (uint256 tokenAmount, uint160 timeswapV2SqrtInterestRateAfter);
}
