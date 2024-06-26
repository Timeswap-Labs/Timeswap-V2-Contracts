// SPDX-License-Identifier: MIT
pragma solidity =0.8.8;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

import {Math} from "@timeswap-labs/v2-library/contracts/Math.sol";
import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";

import {OptionFactoryLibrary} from "@timeswap-labs/v2-option/contracts/libraries/OptionFactory.sol";

import {TimeswapV2OptionBurnParam} from "@timeswap-labs/v2-option/contracts/structs/Param.sol";
import {TimeswapV2OptionBurnCallbackParam} from "@timeswap-labs/v2-option/contracts/structs/CallbackParam.sol";

import {TimeswapV2OptionBurn} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2PoolFactory} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2PoolFactory.sol";
import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {TimeswapV2PoolBurnParam, TimeswapV2PoolCollectTransactionFeesAndShortReturnedParam} from "@timeswap-labs/v2-pool/contracts/structs/Param.sol";
import {TimeswapV2PoolBurnChoiceCallbackParam, TimeswapV2PoolBurnCallbackParam, TimeswapV2PoolAddFeesCallbackParam} from "@timeswap-labs/v2-pool/contracts/structs/CallbackParam.sol";

import {TimeswapV2PoolBurn} from "@timeswap-labs/v2-pool/contracts/enums/Transaction.sol";

import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {ITimeswapV2LiquidityToken} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2LiquidityToken.sol";

import {TimeswapV2TokenMintParam, TimeswapV2TokenBurnParam, TimeswapV2LiquidityTokenBurnParam, TimeswapV2LiquidityTokenCollectParam} from "@timeswap-labs/v2-token/contracts/structs/Param.sol";
import {TimeswapV2TokenMintCallbackParam} from "@timeswap-labs/v2-token/contracts/structs/CallbackParam.sol";

import {ITimeswapV2PeripheryRemoveLiquidityGivenPosition} from "./interfaces/ITimeswapV2PeripheryRemoveLiquidityGivenPosition.sol";

import {TimeswapV2PeripheryRemoveLiquidityGivenPositionParam, FeesAndReturnedDelta, ExcessDelta} from "./structs/Param.sol";
import {TimeswapV2PeripheryRemoveLiquidityGivenPositionChoiceInternalParam, TimeswapV2PeripheryRemoveLiquidityGivenPositionNoBurnChoiceInternalParam, TimeswapV2PeripheryRemoveLiquidityGivenPositionTransferInternalParam} from "./structs/InternalParam.sol";

import {TimeswapV2LiquidityTokenPosition} from "@timeswap-labs/v2-token/contracts/structs/Position.sol";

import {Verify} from "./libraries/Verify.sol";

/// @title Abstract contract which specifies functions that are required for  remove liquidity which are to be inherited for a specific DEX/Aggregator implementation
abstract contract TimeswapV2PeripheryRemoveLiquidityGivenPosition is
  ITimeswapV2PeripheryRemoveLiquidityGivenPosition,
  ERC1155Receiver
{
  using Math for uint256;

  /* ===== MODEL ===== */
  /// @inheritdoc ITimeswapV2PeripheryRemoveLiquidityGivenPosition
  address public immutable override optionFactory;
  /// @inheritdoc ITimeswapV2PeripheryRemoveLiquidityGivenPosition
  address public immutable override poolFactory;
  /// @inheritdoc ITimeswapV2PeripheryRemoveLiquidityGivenPosition
  address public immutable override tokens;
  /// @inheritdoc ITimeswapV2PeripheryRemoveLiquidityGivenPosition
  address public immutable override liquidityTokens;

  /* ===== INIT ===== */

  constructor(
    address chosenOptionFactory,
    address chosenPoolFactory,
    address chosenTokens,
    address chosenLiquidityTokens
  ) {
    optionFactory = chosenOptionFactory;
    poolFactory = chosenPoolFactory;
    tokens = chosenTokens;
    liquidityTokens = chosenLiquidityTokens;
  }

  /// @notice the abstract implementation for remove liquidity function
  /// @param param params for  removeLiquidity as mentioned in the TimeswapV2PeripheryRemoveLiquidityGivenPositionParam struct
  /// @return token0Amount the resulting token0Amount
  /// @return token1Amount the resulting token1Amount
  /// @return feesAndReturnedDelta Delta of fees and short returned
  /// @return excessDelta Delta of excess position
  /// @return data data passed as bytes in the param
  function removeLiquidityGivenPosition(
    TimeswapV2PeripheryRemoveLiquidityGivenPositionParam memory param
  )
    internal
    returns (
      uint256 token0Amount,
      uint256 token1Amount,
      FeesAndReturnedDelta memory feesAndReturnedDelta,
      ExcessDelta memory excessDelta,
      bytes memory data
    )
  {
    (address optionPair, address poolPair) = PoolFactoryLibrary.getWithCheck(
      optionFactory,
      poolFactory,
      param.token0,
      param.token1
    );

    if (param.liquidityAmount != 0)
      ITimeswapV2LiquidityToken(liquidityTokens).burn(
        TimeswapV2LiquidityTokenBurnParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          to: address(this),
          liquidityAmount: param.liquidityAmount,
          data: bytes("")
        })
      );

    (
      feesAndReturnedDelta.long0Fees,
      feesAndReturnedDelta.long1Fees,
      feesAndReturnedDelta.shortFees,
      feesAndReturnedDelta.shortReturned,

    ) = ITimeswapV2LiquidityToken(liquidityTokens).collect(
      TimeswapV2LiquidityTokenCollectParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        from: msg.sender,
        long0FeesTo: address(this),
        long1FeesTo: address(this),
        shortFeesTo: address(this),
        shortReturnedTo: address(this),
        long0FeesDesired: type(uint256).max,
        long1FeesDesired: type(uint256).max,
        shortFeesDesired: type(uint256).max,
        shortReturnedDesired: type(uint256).max,
        data: bytes("")
      })
    );

    excessDelta.long0Amount = feesAndReturnedDelta.long0Fees;
    excessDelta.long1Amount = feesAndReturnedDelta.long1Fees;
    excessDelta.shortAmount = feesAndReturnedDelta.shortFees + feesAndReturnedDelta.shortReturned;

    if (param.liquidityAmount != 0) {
      data = abi.encode(
        param.token0,
        param.token1,
        excessDelta.long0Amount + param.excessLong0Amount,
        excessDelta.long1Amount + param.excessLong1Amount,
        excessDelta.shortAmount + param.excessShortAmount,
        param.data
      );

      uint256 long0AmountFromPool;
      uint256 long1AmountFromPool;
      uint256 shortAmountFromPool;
      (, long0AmountFromPool, long1AmountFromPool, shortAmountFromPool, data) = ITimeswapV2Pool(poolPair).burn(
        TimeswapV2PoolBurnParam({
          strike: param.strike,
          maturity: param.maturity,
          long0To: address(this),
          long1To: address(this),
          shortTo: address(this),
          transaction: TimeswapV2PoolBurn.GivenLiquidity,
          delta: param.liquidityAmount,
          data: data
        })
      );

      excessDelta.long0Amount += long0AmountFromPool;
      excessDelta.long1Amount += long1AmountFromPool;
      excessDelta.shortAmount += shortAmountFromPool;

      (token0Amount, token1Amount, data) = abi.decode(data, (uint256, uint256, bytes));
    } else {
      uint256 tokenAmountWithdraw = (excessDelta.shortAmount + param.excessShortAmount).min(
        StrikeConversion.combine(
          excessDelta.long0Amount + param.excessLong0Amount,
          excessDelta.long1Amount + param.excessLong1Amount,
          param.strike,
          true
        )
      );

      (token0Amount, token1Amount, data) = timeswapV2PeripheryRemoveLiquidityGivenPositionNoBurnChoiceInternal(
        TimeswapV2PeripheryRemoveLiquidityGivenPositionNoBurnChoiceInternalParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          excessToken0Amount: excessDelta.long0Amount + param.excessLong0Amount,
          excessToken1Amount: excessDelta.long1Amount + param.excessLong1Amount,
          tokenAmountWithdraw: tokenAmountWithdraw,
          data: param.data
        })
      );
    }

    if (token0Amount != 0 || token1Amount != 0) {
      data = abi.encode(param.token0, param.token1, msg.sender, excessDelta, data);

      (, , , data) = ITimeswapV2Option(optionPair).burn(
        TimeswapV2OptionBurnParam({
          strike: param.strike,
          maturity: param.maturity,
          token0To: param.token0To,
          token1To: param.token1To,
          transaction: TimeswapV2OptionBurn.GivenTokensAndLongs,
          amount0: token0Amount,
          amount1: token1Amount,
          data: data
        })
      );

      (excessDelta, data) = abi.decode(data, (ExcessDelta, bytes));
    }

    if (
      !(excessDelta.isRemoveLong0 || excessDelta.long0Amount == 0) ||
      !(excessDelta.isRemoveLong1 || excessDelta.long1Amount == 0) ||
      !(excessDelta.isRemoveShort || excessDelta.shortAmount == 0)
    )
      ITimeswapV2Token(tokens).mint(
        TimeswapV2TokenMintParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          long0To: msg.sender,
          long1To: msg.sender,
          shortTo: msg.sender,
          long0Amount: excessDelta.isRemoveLong0 ? 0 : excessDelta.long0Amount,
          long1Amount: excessDelta.isRemoveLong1 ? 0 : excessDelta.long1Amount,
          shortAmount: excessDelta.isRemoveShort ? 0 : excessDelta.shortAmount,
          data: data
        })
      );
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2PoolBurnChoiceCallback
  /// @param param params for calling the implementation specfic poolBurnChoiceCallback to be overriden
  /// @return long0Amount resulting long0 amount
  /// @return long1Amount resulting long1 amount
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PoolBurnChoiceCallback(
    TimeswapV2PoolBurnChoiceCallbackParam calldata param
  ) external returns (uint256 long0Amount, uint256 long1Amount, bytes memory data) {
    address token0;
    address token1;
    uint256 excessLong0Amount;
    uint256 excessLong1Amount;
    uint256 excessShortAmount;
    (token0, token1, excessLong0Amount, excessLong1Amount, excessShortAmount, data) = abi.decode(
      param.data,
      (address, address, uint256, uint256, uint256, bytes)
    );

    Verify.timeswapV2Pool(optionFactory, poolFactory, token0, token1);

    uint256 token0AmountWithdraw;
    uint256 token1AmountWithdraw;

    uint256 tokenAmountWithdraw = (param.shortAmount + excessShortAmount).min(
      param.longAmount + StrikeConversion.combine(excessLong0Amount, excessLong1Amount, param.strike, true)
    );

    (
      long0Amount,
      long1Amount,
      token0AmountWithdraw,
      token1AmountWithdraw,
      data
    ) = timeswapV2PeripheryRemoveLiquidityGivenPositionChoiceInternal(
      TimeswapV2PeripheryRemoveLiquidityGivenPositionChoiceInternalParam({
        token0: token0,
        token1: token1,
        strike: param.strike,
        maturity: param.maturity,
        token0Balance: param.long0Balance,
        token1Balance: param.long1Balance,
        excessToken0Amount: excessLong0Amount,
        excessToken1Amount: excessLong1Amount,
        tokenAmountFromPool: param.longAmount,
        tokenAmountWithdraw: tokenAmountWithdraw,
        data: data
      })
    );

    data = abi.encode(token0AmountWithdraw, token1AmountWithdraw, data);
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2PoolBurnCallback
  /// @param param params for calling the implementation specfic poolBurnCallback to be overriden
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PoolBurnCallback(
    TimeswapV2PoolBurnCallbackParam calldata param
  ) external pure override returns (bytes memory data) {
    data = param.data;
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2OptionBurnCallback
  /// @param param params for calling the implementation specfic optionBurnCallback to be overriden
  /// @return data data passed in bytes in the param passed back
  function timeswapV2OptionBurnCallback(
    TimeswapV2OptionBurnCallbackParam calldata param
  ) external override returns (bytes memory data) {
    address token0;
    address token1;
    address msgSender;
    ExcessDelta memory excessDelta;
    (token0, token1, msgSender, excessDelta, data) = abi.decode(
      param.data,
      (address, address, address, ExcessDelta, bytes)
    );

    Verify.timeswapV2Option(optionFactory, token0, token1);

    excessDelta.isRemoveLong0 = param.token0AndLong0Amount > excessDelta.long0Amount;
    excessDelta.isRemoveLong1 = param.token1AndLong1Amount > excessDelta.long1Amount;
    excessDelta.isRemoveShort = param.shortAmount > excessDelta.shortAmount;

    excessDelta.long0Amount = excessDelta.isRemoveLong0
      ? param.token0AndLong0Amount - excessDelta.long0Amount
      : excessDelta.long0Amount - param.token0AndLong0Amount;
    excessDelta.long1Amount = excessDelta.isRemoveLong1
      ? param.token1AndLong1Amount - excessDelta.long1Amount
      : excessDelta.long1Amount - param.token1AndLong1Amount;
    excessDelta.shortAmount = excessDelta.isRemoveShort
      ? param.shortAmount - excessDelta.shortAmount
      : excessDelta.shortAmount - param.shortAmount;

    if (excessDelta.isRemoveLong0 || excessDelta.isRemoveLong1 || excessDelta.isRemoveShort) {
      data = timeswapV2PeripheryRemoveLiquidityGivenPositionTransferInternal(
        TimeswapV2PeripheryRemoveLiquidityGivenPositionTransferInternalParam({
          token0: token0,
          token1: token1,
          strike: param.strike,
          maturity: param.maturity,
          excessLong0Amount: excessDelta.isRemoveLong0 ? excessDelta.long0Amount : 0,
          excessLong1Amount: excessDelta.isRemoveLong1 ? excessDelta.long1Amount : 0,
          excessShortAmount: excessDelta.isRemoveShort ? excessDelta.shortAmount : 0,
          data: data
        })
      );

      ITimeswapV2Token(tokens).burn(
        TimeswapV2TokenBurnParam({
          token0: token0,
          token1: token1,
          strike: param.strike,
          maturity: param.maturity,
          long0To: address(this),
          long1To: address(this),
          shortTo: address(this),
          long0Amount: excessDelta.isRemoveLong0 ? excessDelta.long0Amount : 0,
          long1Amount: excessDelta.isRemoveLong1 ? excessDelta.long1Amount : 0,
          shortAmount: excessDelta.isRemoveShort ? excessDelta.shortAmount : 0,
          data: bytes("")
        })
      );
    }

    data = abi.encode(excessDelta, data);
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2TokenMintCallback
  /// @param param params for calling the implementation specfic tokenMintCallback to be overriden
  /// @return data data passed in bytes in the param passed back
  function timeswapV2TokenMintCallback(
    TimeswapV2TokenMintCallbackParam calldata param
  ) external returns (bytes memory data) {
    Verify.timeswapV2Token(tokens);

    address optionPair = OptionFactoryLibrary.get(optionFactory, param.token0, param.token1);

    if (param.long0Amount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        msg.sender,
        TimeswapV2OptionPosition.Long0,
        param.long0Amount
      );

    if (param.long1Amount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        msg.sender,
        TimeswapV2OptionPosition.Long1,
        param.long1Amount
      );

    if (param.shortAmount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        msg.sender,
        TimeswapV2OptionPosition.Short,
        param.shortAmount
      );

    data = bytes("");
  }

  /// @notice the virtual function which is to be implemented by the contract that inherits this contract
  /// @param param params for calling the this virtual function
  /// @return token0AmountFromPool The amount of token0 to be withdrawn from the pool
  /// @return token1AmountFromPool The amount of token1 to be withdrawn from the pool
  /// @return token0AmountWithdraw The amount of token0 to be withdrawn to receiver
  /// @return token1AmountWithdraw The amount of token1 to be withdrawn to receiver
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryRemoveLiquidityGivenPositionChoiceInternal(
    TimeswapV2PeripheryRemoveLiquidityGivenPositionChoiceInternalParam memory param
  )
    internal
    virtual
    returns (
      uint256 token0AmountFromPool,
      uint256 token1AmountFromPool,
      uint256 token0AmountWithdraw,
      uint256 token1AmountWithdraw,
      bytes memory data
    );

  /// @notice the virtual function which is to be implemented by the contract that inherits this contract
  /// @param param params for calling the this virtual function
  /// @return token0AmountWithdraw The amount of token0 to be withdrawn to receiver
  /// @return token1AmountWithdraw The amount of token1 to be withdrawn to receiver
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryRemoveLiquidityGivenPositionNoBurnChoiceInternal(
    TimeswapV2PeripheryRemoveLiquidityGivenPositionNoBurnChoiceInternalParam memory param
  ) internal virtual returns (uint256 token0AmountWithdraw, uint256 token1AmountWithdraw, bytes memory data);

  /// @notice the virtual function which is to be implemented by the contract that inherits this contract
  /// @dev This is where the position must be transferred
  /// @param param params for calling the this virtual function
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryRemoveLiquidityGivenPositionTransferInternal(
    TimeswapV2PeripheryRemoveLiquidityGivenPositionTransferInternalParam memory param
  ) internal virtual returns (bytes memory data);
}
