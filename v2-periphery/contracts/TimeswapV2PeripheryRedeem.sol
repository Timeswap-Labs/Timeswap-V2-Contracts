// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {ITimeswapV2OptionFactory} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2OptionFactory.sol";
import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";

import {OptionFactoryLibrary} from "@timeswap-labs/v2-option/contracts/libraries/OptionFactory.sol";

import {TimeswapV2OptionBurnParam} from "@timeswap-labs/v2-option/contracts/structs/Param.sol";
import {TimeswapV2OptionBurn} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2PoolFactory} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2PoolFactory.sol";
import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";
import {TimeswapV2TokenPosition} from "@timeswap-labs/v2-token/contracts/structs/Position.sol";
import {TimeswapV2TokenBurnParam} from "@timeswap-labs/v2-token/contracts/structs/Param.sol";

import {TimeswapV2PeripheryRedeemParam} from "./structs/Param.sol";

import {ITimeswapV2PeripheryRedeem} from "./interfaces/ITimeswapV2PeripheryRedeem.sol"; //TODO: Add interface
import {Verify} from "./libraries/Verify.sol";

/// @title Abstract contract which specifies functions that are required for  redeem which are to be inherited for a specific DEX/Aggregator implementation

abstract contract TimeswapV2PeripheryRedeem is ERC1155Receiver, ITimeswapV2PeripheryRedeem {
  /* ===== MODEL ===== */
  /// @inheritdoc ITimeswapV2PeripheryRedeem
  address public immutable override optionFactory;
  /// @inheritdoc ITimeswapV2PeripheryRedeem
  address public immutable override tokens;

  /* ===== INIT ===== */

  constructor(address chosenOptionFactory, address chosenTokens) {
    optionFactory = chosenOptionFactory;
    tokens = chosenTokens;
  }

  /// @notice the abstract implementation for redeem function
  /// @param param params for  redeem as mentioned in the TimeswapV2PeripheryRedeemParam struct
  /// @return shortAmount resulting short amount
  function redeem(TimeswapV2PeripheryRedeemParam memory param) internal returns (uint256 shortAmount) {
    address optionPair = OptionFactoryLibrary.getWithCheck(optionFactory, param.token0, param.token1);

    // Unwrap any matching amount of long and short
    // Will revert if there is not enough short position to burn
    ITimeswapV2Token(tokens).burn(
      TimeswapV2TokenBurnParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        long0To: address(this),
        long1To: address(this),
        shortTo: address(this),
        long0Amount: param.token0AndLong0Amount,
        long1Amount: param.token1AndLong1Amount,
        shortAmount: StrikeConversion.combine(
          param.token0AndLong0Amount,
          param.token1AndLong1Amount,
          param.strike,
          true
        ),
        data: bytes("")
      })
    );

    // Burn the unwrapped matching amount of long and short to withdraw the underlying ERC20
    (, , shortAmount, ) = ITimeswapV2Option(optionPair).burn(
      TimeswapV2OptionBurnParam({
        strike: param.strike,
        maturity: param.maturity,
        token0To: param.token0To,
        token1To: param.token1To,
        transaction: TimeswapV2OptionBurn.GivenTokensAndLongs,
        amount0: param.token0AndLong0Amount,
        amount1: param.token1AndLong1Amount,
        data: bytes("")
      })
    );
  }
}
