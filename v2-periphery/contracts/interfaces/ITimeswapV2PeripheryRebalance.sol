// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2OptionMintCallback} from "@timeswap-labs/v2-option/contracts/interfaces/callbacks/ITimeswapV2OptionMintCallback.sol";
import {ITimeswapV2OptionSwapCallback} from "@timeswap-labs/v2-option/contracts/interfaces/callbacks/ITimeswapV2OptionSwapCallback.sol";

import {ITimeswapV2PoolRebalanceCallback} from "@timeswap-labs/v2-pool/contracts/interfaces/callbacks/ITimeswapV2PoolRebalanceCallback.sol";

import {ITimeswapV2TokenMintCallback} from "@timeswap-labs/v2-token/contracts/interfaces/callbacks/ITimeswapV2TokenMintCallback.sol";

/// @title An interface for TS-V2 Periphery Rebalance
interface ITimeswapV2PeripheryRebalance is
  ITimeswapV2OptionMintCallback,
  ITimeswapV2OptionSwapCallback,
  ITimeswapV2PoolRebalanceCallback,
  ITimeswapV2TokenMintCallback
{
  /// @dev Returns the option factory address.
  /// @return optionFactory The option factory address.
  function optionFactory() external returns (address);

  /// @dev Returns the pool factory address.
  /// @return poolFactory The pool factory address.
  function poolFactory() external returns (address);

  /// @dev Return the tokens address
  function tokens() external returns (address);
}
