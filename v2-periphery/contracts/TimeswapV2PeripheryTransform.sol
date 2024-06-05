// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";

import {OptionFactoryLibrary} from "@timeswap-labs/v2-option/contracts/libraries/OptionFactory.sol";

import {TimeswapV2OptionSwapParam} from "@timeswap-labs/v2-option/contracts/structs/Param.sol";
import {TimeswapV2OptionSwapCallbackParam} from "@timeswap-labs/v2-option/contracts/structs/CallbackParam.sol";

import {TimeswapV2OptionSwap} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenMintParam, TimeswapV2TokenBurnParam} from "@timeswap-labs/v2-token/contracts/structs/Param.sol";
import {TimeswapV2TokenMintCallbackParam} from "@timeswap-labs/v2-token/contracts/structs/CallbackParam.sol";

import {ITimeswapV2PeripheryTransform} from "./interfaces/ITimeswapV2PeripheryTransform.sol";

import {TimeswapV2PeripheryTransformParam} from "./structs/Param.sol";
import {TimeswapV2PeripheryTransformInternalParam} from "./structs/InternalParam.sol";

import {Verify} from "./libraries/Verify.sol";

/// @title Abstract contract which specifies functions that are required for transform which are to be inherited for a specific DEX/Aggregator implementation
abstract contract TimeswapV2PeripheryTransform is ITimeswapV2PeripheryTransform, ERC1155Receiver {
  /* ===== MODEL ===== */
  /// @inheritdoc ITimeswapV2PeripheryTransform
  address public immutable override optionFactory;
  /// @inheritdoc ITimeswapV2PeripheryTransform
  address public immutable override tokens;

  /* ===== INIT ===== */

  constructor(address chosenOptionFactory, address chosenTokens) {
    optionFactory = chosenOptionFactory;

    tokens = chosenTokens;
  }

  /// @notice the abstract implementation for transform function
  /// @param param params for  transform as mentioned in the TimeswapV2PeripheryTransformParam struct
  /// @return token0AndLong0Amount resulting token0AndLong0Amount amount
  /// @return token1AndLong1Amount resulting token0AndLong0Amount amount
  /// @return data data passed as bytes in the param
  function transform(
    TimeswapV2PeripheryTransformParam memory param
  ) internal returns (uint256 token0AndLong0Amount, uint256 token1AndLong1Amount, bytes memory data) {
    address optionPair = OptionFactoryLibrary.getWithCheck(optionFactory, param.token0, param.token1);

    data = abi.encode(param.token0, param.token1, param.tokenTo, param.longTo, param.data);

    // Unwrap the long0 or long1 ERC1155
    ITimeswapV2Token(tokens).burn(
      TimeswapV2TokenBurnParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        long0To: param.isLong0ToLong1 ? msg.sender : address(this),
        long1To: param.isLong0ToLong1 ? address(this) : msg.sender,
        shortTo: address(this),
        long0Amount: param.isLong0ToLong1 ? param.positionAmount : 0,
        long1Amount: param.isLong0ToLong1 ? 0 : param.positionAmount,
        shortAmount: 0,
        data: bytes("")
      })
    );

    // Transform long0 to long1 or long1 to long0
    // The next logic goes to the timeswapV2OptionSwapCallback function
    (token0AndLong0Amount, token1AndLong1Amount, data) = ITimeswapV2Option(optionPair).swap(
      TimeswapV2OptionSwapParam({
        strike: param.strike,
        maturity: param.maturity,
        tokenTo: param.tokenTo,
        longTo: address(this),
        isLong0ToLong1: param.isLong0ToLong1,
        transaction: param.isLong0ToLong1
          ? TimeswapV2OptionSwap.GivenToken0AndLong0
          : TimeswapV2OptionSwap.GivenToken1AndLong1,
        amount: param.positionAmount,
        data: data
      })
    );
  }

  /// @notice the abstract implementation for TimeswapV2OptionSwapCallback
  /// @param param params for swapCallBack from TimeswapV2Option
  /// @return data data passed in bytes in the param passed back
  function timeswapV2OptionSwapCallback(
    TimeswapV2OptionSwapCallbackParam calldata param
  ) external returns (bytes memory data) {
    address token0;
    address token1;
    address tokenTo;
    address longTo;
    (token0, token1, tokenTo, longTo, data) = abi.decode(param.data, (address, address, address, address, bytes));

    Verify.timeswapV2Option(optionFactory, token0, token1);

    // Wrap the newly transformed long position as ERC1155
    // The next logic goes to the timeswapV2TokenMintCallback function
    ITimeswapV2Token(tokens).mint(
      TimeswapV2TokenMintParam({
        token0: token0,
        token1: token1,
        strike: param.strike,
        maturity: param.maturity,
        long0To: param.isLong0ToLong1 ? address(this) : longTo,
        long1To: param.isLong0ToLong1 ? longTo : address(this),
        shortTo: address(this),
        long0Amount: param.isLong0ToLong1 ? 0 : param.token0AndLong0Amount,
        long1Amount: param.isLong0ToLong1 ? param.token1AndLong1Amount : 0,
        shortAmount: 0,
        data: bytes("")
      })
    );

    // Ask the inheritor contract to tranfer the required ERC20 to the option pair contract
    data = timeswapV2PeripheryTransformInternal(
      TimeswapV2PeripheryTransformInternalParam({
        optionPair: msg.sender,
        token0: token0,
        token1: token1,
        strike: param.strike,
        maturity: param.maturity,
        isLong0ToLong1: param.isLong0ToLong1,
        token0AndLong0Amount: param.token0AndLong0Amount,
        token1AndLong1Amount: param.token1AndLong1Amount,
        data: data
      })
    );

    // The next logic goes back to after the TimeswapV2Option swap function was called
  }

  /// @notice the abstract implementation for TimeswapV2TokenMintCallback
  /// @param param params for mintCallBack from TimeswapV2Token
  /// @return data data passed in bytes in the param passed back
  function timeswapV2TokenMintCallback(
    TimeswapV2TokenMintCallbackParam calldata param
  ) external returns (bytes memory data) {
    Verify.timeswapV2Token(tokens);

    address optionPair = OptionFactoryLibrary.get(optionFactory, param.token0, param.token1);

    ITimeswapV2Option(optionPair).transferPosition(
      param.strike,
      param.maturity,
      msg.sender,
      param.long0Amount != 0 ? TimeswapV2OptionPosition.Long0 : TimeswapV2OptionPosition.Long1,
      param.long0Amount != 0 ? param.long0Amount : param.long1Amount
    );

    data = bytes("");

    // The next logic goes back to after the TimeswapV2Token mint function was called
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2Transform
  /// @param param params for calling the implementation specfic transform to be overriden
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryTransformInternal(
    TimeswapV2PeripheryTransformInternalParam memory param
  ) internal virtual returns (bytes memory data);
}
