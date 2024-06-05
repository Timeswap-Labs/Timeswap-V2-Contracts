// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import {ITimeswapV2PoolLeverageCallback} from "@timeswap-labs/v2-pool/contracts/interfaces/callbacks/ITimeswapV2PoolLeverageCallback.sol";

import {ITimeswapV2TokenBurnCallback} from "@timeswap-labs/v2-token/contracts/interfaces/callbacks/ITimeswapV2TokenBurnCallback.sol";

/// @title An interface for TS-V2 Periphery Close Lend Given Position
interface ITimeswapV2PeripheryQuoterCloseLendGivenPosition is
  ITimeswapV2PoolLeverageCallback,
  ITimeswapV2TokenBurnCallback,
  IERC1155Receiver
{
  error PassTokenBurnCallbackInfo(
    uint160 timeswapV2SqrtInterestRateAfter,
    uint256 token0Amount,
    uint256 token1Amount,
    bytes data
  );

  error PassPoolLeverageCallbackInfo(
    uint160 timeswapV2SqrtInterestRateAfter,
    uint256 token0Amount,
    uint256 token1Amount,
    bytes data
  );

  /// @dev Returns the option factory address.
  /// @return optionFactory The option factory address.
  function optionFactory() external returns (address);

  /// @dev Returns the pool factory address.
  /// @return poolFactory The pool factory address.
  function poolFactory() external returns (address);

  /// @dev Return the tokens address
  function tokens() external returns (address);
}
