// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {FeeCalculation} from "@timeswap-labs/v2-pool/contracts/libraries/FeeCalculation.sol";

struct PoolPosition {
  uint256 long0FeeGrowth;
  uint256 long1FeeGrowth;
  uint256 shortFeeGrowth;
  uint256 shortReturnedGrowth;
}

library PoolPositionLibrary {
  /// @dev update fee for a given position, liquidity and respective feeGrowth
  function update(
    PoolPosition storage poolPosition,
    uint160 liquidity,
    uint256 long0Fees,
    uint256 long1Fees,
    uint256 shortFees,
    uint256 shortReturned
  ) internal {
    poolPosition.long0FeeGrowth += FeeCalculation.getFeeGrowth(long0Fees, liquidity);
    poolPosition.long1FeeGrowth += FeeCalculation.getFeeGrowth(long1Fees, liquidity);
    poolPosition.shortFeeGrowth += FeeCalculation.getFeeGrowth(shortFees, liquidity);
    poolPosition.shortReturnedGrowth += FeeCalculation.getFeeGrowth(shortReturned, liquidity);
  }

  function getFeesAndShortReturnedGrowth(
    PoolPosition memory poolPosition,
    uint160 liquidity,
    uint256 long0Fees,
    uint256 long1Fees,
    uint256 shortFees,
    uint256 shortReturned
  )
    internal
    pure
    returns (uint256 long0FeeGrowth, uint256 long1FeeGrowth, uint256 shortFeeGrowth, uint256 shortReturnedGrowth)
  {
    long0FeeGrowth = poolPosition.long0FeeGrowth + FeeCalculation.getFeeGrowth(long0Fees, liquidity);
    long1FeeGrowth = poolPosition.long1FeeGrowth + FeeCalculation.getFeeGrowth(long1Fees, liquidity);
    shortFeeGrowth = poolPosition.shortFeeGrowth + FeeCalculation.getFeeGrowth(shortFees, liquidity);
    shortReturnedGrowth = poolPosition.shortReturnedGrowth + FeeCalculation.getFeeGrowth(shortReturned, liquidity);
  }
}
