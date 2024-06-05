// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

/// @title ERC20TokenSweeper interface
/// @notice Functions to ease sweeping of ERC20 tokens held by the contract
interface IERC20TokenSweeper {
  /// @notice Transfers the full amount of a token held by this contract to recipient
  /// @dev The amountMinimum parameter prevents malicious contracts from stealing the token from users
  /// @param token The contract address of the token which will be transferred to `recipient`
  /// @param amountMinimum The minimum amount of token required for a transfer
  /// @param recipient The destination address of the token
  function sweepERC20Token(address token, uint256 amountMinimum, address recipient) external payable;
}
