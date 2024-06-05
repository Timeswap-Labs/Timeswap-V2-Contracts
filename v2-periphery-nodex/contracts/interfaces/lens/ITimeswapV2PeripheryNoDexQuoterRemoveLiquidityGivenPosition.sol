// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2PeripheryQuoterRemoveLiquidityGivenPosition} from "@timeswap-labs/v2-periphery/contracts/interfaces/lens/ITimeswapV2PeripheryQuoterRemoveLiquidityGivenPosition.sol";
import {FeesAndReturnedDelta, ExcessDelta} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";

import {IMulticall} from "../IMulticall.sol";

import {TimeswapV2PeripheryNoDexQuoterRemoveLiquidityGivenPositionParam} from "../../structs/lens/QuoterParam.sol";

/// @title An interface for TS-V2 Periphery NoDex RemoveLiquidity Quoter.
interface ITimeswapV2PeripheryNoDexQuoterRemoveLiquidityGivenPosition is
  ITimeswapV2PeripheryQuoterRemoveLiquidityGivenPosition,
  IMulticall
{
  /// @dev The remove liquidity function.
  /// @param param Remove liquidity param.
  /// @param durationForward The time moved forward for quotation.
  /// @return token0Amount
  /// @return token1Amount
  /// @return feesAndReturnedDelta
  /// @return excessDelta
  /// @return timeswapV2LiquidityAfter
  function removeLiquidityGivenPosition(
    TimeswapV2PeripheryNoDexQuoterRemoveLiquidityGivenPositionParam calldata param,
    uint96 durationForward
  )
    external
    returns (
      uint256 token0Amount,
      uint256 token1Amount,
      FeesAndReturnedDelta memory feesAndReturnedDelta,
      ExcessDelta memory excessDelta,
      uint160 timeswapV2LiquidityAfter
    );
}
