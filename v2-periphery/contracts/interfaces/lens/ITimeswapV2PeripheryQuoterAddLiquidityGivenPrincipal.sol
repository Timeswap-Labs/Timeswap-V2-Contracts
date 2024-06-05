// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2OptionMintCallback} from "@timeswap-labs/v2-option/contracts/interfaces/callbacks/ITimeswapV2OptionMintCallback.sol";

import {ITimeswapV2PoolMintCallback} from "@timeswap-labs/v2-pool/contracts/interfaces/callbacks/ITimeswapV2PoolMintCallback.sol";

import {ITimeswapV2TokenMintCallback} from "@timeswap-labs/v2-token/contracts/interfaces/callbacks/ITimeswapV2TokenMintCallback.sol";

import {ITimeswapV2LiquidityTokenMintCallback} from "@timeswap-labs/v2-token/contracts/interfaces/callbacks/ITimeswapV2LiquidityTokenMintCallback.sol";

/// @title An interface for TS-V2 Periphery Add Liquidity Given Principal
interface ITimeswapV2PeripheryQuoterAddLiquidityGivenPrincipal is
  ITimeswapV2OptionMintCallback,
  ITimeswapV2PoolMintCallback,
  ITimeswapV2TokenMintCallback,
  ITimeswapV2LiquidityTokenMintCallback
{
  error PassOptionMintCallbackInfo(uint256 shortAmountMinted, bytes data);

  error PassPoolMintCallbackInfo(uint160 liquidityAmount, uint160 timeswapV2LiquidityAfter, bytes data);

  error PassLiquidityTokenMintCallbackInfo();

  error PassTokenMintCallbackInfo();

  /// @dev Returns the option factory address.
  function optionFactory() external returns (address);

  /// @dev Returns the pool factory address.
  function poolFactory() external returns (address);

  /// @dev Returns the tokens address.
  function tokens() external returns (address);

  /// @dev Return the liquidity tokens address
  function liquidityTokens() external returns (address);
}
