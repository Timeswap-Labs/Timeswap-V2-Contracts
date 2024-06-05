// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {ITimeswapV2OptionFactory} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2OptionFactory.sol";
import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {OptionFactoryLibrary} from "@timeswap-labs/v2-option/contracts/libraries/OptionFactory.sol";

import {TimeswapV2OptionMintParam, TimeswapV2OptionSwapParam} from "@timeswap-labs/v2-option/contracts/structs/Param.sol";
import {TimeswapV2OptionMintCallbackParam, TimeswapV2OptionSwapCallbackParam} from "@timeswap-labs/v2-option/contracts/structs/CallbackParam.sol";

import {TimeswapV2OptionMint, TimeswapV2OptionSwap} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";

import {ITimeswapV2PoolFactory} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2PoolFactory.sol";
import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {TimeswapV2PoolRebalanceParam} from "@timeswap-labs/v2-pool/contracts/structs/Param.sol";
import {TimeswapV2PoolRebalanceCallbackParam} from "@timeswap-labs/v2-pool/contracts/structs/CallbackParam.sol";

import {TimeswapV2PoolRebalance} from "@timeswap-labs/v2-pool/contracts/enums/Transaction.sol";

import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenMintParam} from "@timeswap-labs/v2-token/contracts/structs/Param.sol";
import {TimeswapV2TokenMintCallbackParam} from "@timeswap-labs/v2-token/contracts/structs/CallbackParam.sol";

import {ITimeswapV2PeripheryRebalance} from "./interfaces/ITimeswapV2PeripheryRebalance.sol";

import {TimeswapV2PeripheryRebalanceParam} from "./structs/Param.sol";
import {TimeswapV2PeripheryRebalanceInternalParam} from "./structs/InternalParam.sol";

import {Verify} from "./libraries/Verify.sol";

/// @title Abstract contract which specifies functions that are required for rebalance which are to be inherited for a specific DEX/Aggregator implementation
abstract contract TimeswapV2PeripheryRebalance is ITimeswapV2PeripheryRebalance {
  /* ===== MODEL ===== */
  /// @inheritdoc ITimeswapV2PeripheryRebalance
  address public immutable override optionFactory;
  /// @inheritdoc ITimeswapV2PeripheryRebalance
  address public immutable override poolFactory;
  /// @inheritdoc ITimeswapV2PeripheryRebalance
  address public immutable override tokens;

  /* ===== INIT ===== */

  constructor(address chosenOptionFactory, address chosenPoolFactory, address chosenTokens) {
    optionFactory = chosenOptionFactory;
    poolFactory = chosenPoolFactory;
    tokens = chosenTokens;
  }

  /// @notice the abstract implementation for rebalance function
  /// @param param params for  timeswapV2Rebalance as mentioned in the TimeswapV2PeripheryRebalanceParam struct
  /// @return token0Amount the amount of token0
  /// @return token1Amount the amount of token1 chosen
  /// @return excessShortAmount the amount of excessShort
  /// @return data data passed as bytes in the param
  function rebalance(
    TimeswapV2PeripheryRebalanceParam memory param
  ) internal returns (uint256 token0Amount, uint256 token1Amount, uint256 excessShortAmount, bytes memory data) {
    (, address poolPair) = PoolFactoryLibrary.getWithCheck(optionFactory, poolFactory, param.token0, param.token1);

    data = abi.encode(param.token0, param.token1, param.tokenTo, param.excessShortTo, param.data);

    // Call the rebalance function
    // The next logic goes to the timeswapV2PoolRebalanceCallback function
    (token0Amount, token1Amount, data) = ITimeswapV2Pool(poolPair).rebalance(
      TimeswapV2PoolRebalanceParam({
        strike: param.strike,
        maturity: param.maturity,
        to: address(this),
        isLong0ToLong1: param.isLong0ToLong1,
        transaction: param.givenLong0 ? TimeswapV2PoolRebalance.GivenLong0 : TimeswapV2PoolRebalance.GivenLong1,
        delta: param.tokenAmount,
        data: data
      })
    );

    (excessShortAmount, data) = abi.decode(data, (uint256, bytes));
  }

  /// @notice the abstract implementation for rebalanceCallback function
  /// @param param params for  rebalanceCallback as mentioned in the TimeswapV2PoolRebalanceCallbackParam struct
  /// @return data data passed as bytes in the param
  function timeswapV2PoolRebalanceCallback(
    TimeswapV2PoolRebalanceCallbackParam calldata param
  ) external returns (bytes memory data) {
    address token0;
    address token1;
    address tokenTo;
    address excessShortTo;
    (token0, token1, tokenTo, excessShortTo, data) = abi.decode(
      param.data,
      (address, address, address, address, bytes)
    );

    address optionPair = Verify.timeswapV2Pool(optionFactory, poolFactory, token0, token1);

    data = abi.encode(
      msg.sender,
      token0,
      token1,
      excessShortTo,
      param.isLong0ToLong1 ? param.long0Amount : param.long1Amount,
      data
    );

    // Do a swap to transform long0 to long1 or long1 to long0
    // The next logic goes to the timeswapV2OptionSwapCallback function
    (, , data) = ITimeswapV2Option(optionPair).swap(
      TimeswapV2OptionSwapParam({
        strike: param.strike,
        maturity: param.maturity,
        tokenTo: tokenTo,
        longTo: msg.sender,
        isLong0ToLong1: !param.isLong0ToLong1,
        transaction: param.isLong0ToLong1
          ? TimeswapV2OptionSwap.GivenToken1AndLong1
          : TimeswapV2OptionSwap.GivenToken0AndLong0,
        amount: param.isLong0ToLong1 ? param.long1Amount : param.long0Amount,
        data: data
      })
    );

    // The next logic goes back to after the TimeswapV2Pool rebalance function was called
  }

  /// @notice the abstract implementation for TimeswapV2OptionSwapCallback
  /// @param param params for swapCallBack from TimeswapV2Option
  /// @return data data passed in bytes in the param passed back
  function timeswapV2OptionSwapCallback(
    TimeswapV2OptionSwapCallbackParam calldata param
  ) external override returns (bytes memory data) {
    address poolPair;
    address token0;
    address token1;
    address excessShortTo;
    uint256 depositAmount;
    (poolPair, token0, token1, excessShortTo, depositAmount, data) = abi.decode(
      param.data,
      (address, address, address, address, uint256, bytes)
    );

    Verify.timeswapV2Option(optionFactory, token0, token1);

    uint256 longAmount = depositAmount -
      (param.isLong0ToLong1 ? param.token1AndLong1Amount : param.token0AndLong0Amount);

    data = abi.encode(
      token0,
      token1,
      excessShortTo,
      !param.isLong0ToLong1,
      depositAmount,
      param.isLong0ToLong1 ? param.token0AndLong0Amount : param.token1AndLong1Amount,
      data
    );

    // Mint the required amount of long and short
    // The next logic goes to the timeswapV2OptionMintCallback function
    (, , , data) = ITimeswapV2Option(msg.sender).mint(
      TimeswapV2OptionMintParam({
        strike: param.strike,
        maturity: param.maturity,
        long0To: param.isLong0ToLong1 ? address(this) : poolPair,
        long1To: param.isLong0ToLong1 ? poolPair : address(this),
        shortTo: address(this),
        transaction: TimeswapV2OptionMint.GivenTokensAndLongs,
        amount0: param.isLong0ToLong1 ? 0 : longAmount,
        amount1: param.isLong0ToLong1 ? longAmount : 0,
        data: data
      })
    );

    // The next logic goes back to after the TimeswapV2Pool swap function was called
  }

  /// @notice the abstract implementation for TimeswapV2OptionMintCallback
  /// @param param params for mintCallBack from TimeswapV2Option
  /// @return data data passed in bytes in the param passed back
  function timeswapV2OptionMintCallback(
    TimeswapV2OptionMintCallbackParam memory param
  ) external override returns (bytes memory data) {
    address token0;
    address token1;
    address excessShortTo;
    bool isLong0ToLong1;
    uint256 depositAmount;
    uint256 withdrawAmount;
    (token0, token1, excessShortTo, isLong0ToLong1, depositAmount, withdrawAmount, data) = abi.decode(
      param.data,
      (address, address, address, bool, uint256, uint256, bytes)
    );

    Verify.timeswapV2Option(optionFactory, token0, token1);

    data = abi.encode(msg.sender, isLong0ToLong1, depositAmount, withdrawAmount, data);

    // Wrap the short minted as ERC1155
    // The next logic goes to the timeswapV2TokenMintCallback function
    data = ITimeswapV2Token(tokens).mint(
      TimeswapV2TokenMintParam({
        token0: token0,
        token1: token1,
        strike: param.strike,
        maturity: param.maturity,
        long0To: address(this),
        long1To: address(this),
        shortTo: excessShortTo,
        long0Amount: 0,
        long1Amount: 0,
        shortAmount: param.shortAmount,
        data: data
      })
    );

    // The next logic goes back to the TimeswapV2Option mint function was called
  }

  /// @notice the abstract implementation for TimeswapV2TokenMintCallback
  /// @param param params for mintCallBack from TimeswapV2Token
  /// @return data data passed in bytes in the param passed back
  function timeswapV2TokenMintCallback(
    TimeswapV2TokenMintCallbackParam calldata param
  ) external override returns (bytes memory data) {
    address optionPair;
    bool isLong0ToLong1;
    uint256 depositAmount;
    uint256 withdrawAmount;
    (optionPair, isLong0ToLong1, depositAmount, withdrawAmount, data) = abi.decode(
      param.data,
      (address, bool, uint256, uint256, bytes)
    );

    Verify.timeswapV2Token(tokens);

    ITimeswapV2Option(optionPair).transferPosition(
      param.strike,
      param.maturity,
      msg.sender,
      TimeswapV2OptionPosition.Short,
      param.shortAmount
    );

    // Ask the inheritor contract to transfer the required ERC20 to the option pair contract
    data = timeswapV2PeripheryRebalanceInternal(
      TimeswapV2PeripheryRebalanceInternalParam({
        optionPair: optionPair,
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        isLong0ToLong1: isLong0ToLong1,
        token0Amount: isLong0ToLong1 ? depositAmount : withdrawAmount,
        token1Amount: isLong0ToLong1 ? withdrawAmount : depositAmount,
        excessShortAmount: param.shortAmount,
        data: data
      })
    );

    data = abi.encode(param.shortAmount, data);

    // The next logic goes back to after the TimeswapV2Token mint function was called
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2Rebalance
  /// @param param params for calling the implementation specfic rebalance to be overriden
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryRebalanceInternal(
    TimeswapV2PeripheryRebalanceInternalParam memory param
  ) internal virtual returns (bytes memory data);
}
