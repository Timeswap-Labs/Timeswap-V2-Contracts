// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2PeripheryBorrowGivenPosition} from "@timeswap-labs/v2-periphery/contracts/interfaces/ITimeswapV2PeripheryBorrowGivenPosition.sol";

import {TimeswapV2PeripheryNoDexBorrowGivenPositionParam} from "../structs/Param.sol";

import {INativeWithdraws} from "./INativeWithdraws.sol";
import {INativePayments} from "./INativePayments.sol";
import {IMulticall} from "./IMulticall.sol";

/// @title An interface for TS-V2 Periphery No Dex Borrow Given Position.
interface ITimeswapV2PeripheryNoDexBorrowGivenPosition is
  ITimeswapV2PeripheryBorrowGivenPosition,
  INativeWithdraws,
  INativePayments,
  IMulticall
{
  event BorrowGivenPosition(
    address indexed token0,
    address indexed token1,
    uint256 strike,
    uint256 indexed maturity,
    address from,
    address tokenTo,
    address longTo,
    bool isToken0,
    bool isLong0,
    uint256 tokenAmount,
    uint256 positionAmount
  );

  error MinTokenReached(uint256 tokenAmount, uint256 minTokenAmount);

  /// @dev The borrow given position function.
  /// @param param Borrow given position param.
  /// @return tokenAmount
  function borrowGivenPosition(
    TimeswapV2PeripheryNoDexBorrowGivenPositionParam calldata param
  ) external payable returns (uint256 tokenAmount);
}
