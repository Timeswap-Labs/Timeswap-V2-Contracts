// SPDX-License-Identifier: MIT
pragma solidity =0.8.8;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import {ITimeswapV2OptionBurnCallback} from "@timeswap-labs/v2-option/contracts/interfaces/callbacks/ITimeswapV2OptionBurnCallback.sol";

import {ITimeswapV2PoolBurnCallback} from "@timeswap-labs/v2-pool/contracts/interfaces/callbacks/ITimeswapV2PoolBurnCallback.sol";

import {ITimeswapV2TokenMintCallback} from "@timeswap-labs/v2-token/contracts/interfaces/callbacks/ITimeswapV2TokenMintCallback.sol";

/// @title An interface for TS-V2 Periphery Remove Liquidity
interface ITimeswapV2PeripheryRemoveLiquidityGivenPosition is
  ITimeswapV2OptionBurnCallback,
  ITimeswapV2PoolBurnCallback,
  ITimeswapV2TokenMintCallback,
  IERC1155Receiver
{
  /// @dev Returns the option factory address.
  function optionFactory() external returns (address);

  /// @dev Returns the pool factory address.
  function poolFactory() external returns (address);

  /// @dev Returns the tokens address.
  function tokens() external returns (address);

  /// @dev Returns the liquidity tokens address.
  function liquidityTokens() external returns (address);
}
