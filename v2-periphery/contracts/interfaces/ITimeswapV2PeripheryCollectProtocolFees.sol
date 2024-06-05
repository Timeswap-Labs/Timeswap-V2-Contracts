// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2TokenMintCallback} from "@timeswap-labs/v2-token/contracts/interfaces/callbacks/ITimeswapV2TokenMintCallback.sol";
import {IOwnableTwoSteps} from "@timeswap-labs/v2-pool/contracts/interfaces/IOwnableTwoSteps.sol";

/// @title An interface for TS-V2 Periphery Collect Protocol Fees
interface ITimeswapV2PeripheryCollectProtocolFees is IOwnableTwoSteps, ITimeswapV2TokenMintCallback {
  error RequireDeploymentOfOption(address token0, address token1);

  error RequireDeploymentOfPool(address token0, address token1);

  /// @dev Returns the option factory address.
  /// @return optionFactory The option factory address.
  function optionFactory() external returns (address);

  /// @dev Returns the pool factory address.
  /// @return poolFactory The pool factory address.
  function poolFactory() external returns (address);

  /// @dev Return the tokens address
  function tokens() external returns (address);

  /// @dev Sets the address for the new owner for the pool factory.
  function set(address chosenPendingOwner) external;

  /// @dev Accepts the new owner as the owner for the pool factory.
  function accept() external;
}
