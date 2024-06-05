// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

/// @title An interface for TS-V2 Periphery Collect
interface ITimeswapV2PeripheryCollect is IERC1155Receiver {
  /// @dev Returns the option factory address.
  function optionFactory() external returns (address);

  /// @dev Return the tokens address
  function tokens() external returns (address);

  /// @dev Returns the liquidity tokens address.
  function liquidityTokens() external returns (address);
}
