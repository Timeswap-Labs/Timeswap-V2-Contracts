// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";
import {CatchError} from "@timeswap-labs/v2-library/contracts/CatchError.sol";

import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";

import {ITimeswapV2OptionFactory} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2OptionFactory.sol";
import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";

import {TimeswapV2OptionMintParam, TimeswapV2OptionSwapParam} from "@timeswap-labs/v2-option/contracts/structs/Param.sol";
import {TimeswapV2OptionMintCallbackParam, TimeswapV2OptionSwapCallbackParam} from "@timeswap-labs/v2-option/contracts/structs/CallbackParam.sol";
import {TimeswapV2OptionSwap} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";
import {TimeswapV2OptionMint} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {TimeswapV2PoolLeverageParam} from "@timeswap-labs/v2-pool/contracts/structs/Param.sol";
import {TimeswapV2PoolLeverageChoiceCallbackParam, TimeswapV2PoolLeverageCallbackParam} from "@timeswap-labs/v2-pool/contracts/structs/CallbackParam.sol";

import {TimeswapV2PoolLeverage} from "@timeswap-labs/v2-pool/contracts/enums/Transaction.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenMintParam} from "@timeswap-labs/v2-token/contracts/structs/Param.sol";
import {TimeswapV2TokenMintCallbackParam} from "@timeswap-labs/v2-token/contracts/structs/CallbackParam.sol";

import {ITimeswapV2PeripheryQuoterBorrowGivenPosition} from "../interfaces/lens/ITimeswapV2PeripheryQuoterBorrowGivenPosition.sol";

import {TimeswapV2PeripheryBorrowGivenPositionParam} from "../structs/Param.sol";
import {TimeswapV2PeripheryBorrowGivenPositionChoiceInternalParam, TimeswapV2PeripheryBorrowGivenPositionInternalParam} from "../structs/InternalParam.sol";

import {Verify} from "../libraries/Verify.sol";

/// @title Abstract contract which specifies functions that are required for borrow given position which are to be inherited for a specific DEX/Aggregator implementation
abstract contract TimeswapV2PeripheryQuoterBorrowGivenPosition is ITimeswapV2PeripheryQuoterBorrowGivenPosition {
  using CatchError for bytes;

  /* ===== MODEL ===== */
  /// @inheritdoc ITimeswapV2PeripheryQuoterBorrowGivenPosition
  address public immutable override optionFactory;
  /// @inheritdoc ITimeswapV2PeripheryQuoterBorrowGivenPosition
  address public immutable override poolFactory;
  /// @inheritdoc ITimeswapV2PeripheryQuoterBorrowGivenPosition
  address public immutable override tokens;

  /* ===== INIT ===== */

  constructor(address chosenOptionFactory, address chosenPoolFactory, address chosenTokens) {
    optionFactory = chosenOptionFactory;
    poolFactory = chosenPoolFactory;
    tokens = chosenTokens;
  }

  /// @notice the abstract implementation for borrowGivenPosition function
  /// @param param params for  borrowGivenPosition as mentioned in the TimeswapV2PeripheryBorrowGivenPositionParam struct
  /// @param durationForward the amount of seconds moved forward
  /// @return token0Amount the amount of token0
  /// @return token1Amount the amount of token1
  /// @return data data passed as bytes in the param
  /// @return timeswapV2SqrtInterestRateAfter the new sqrt interest rate after this transaction
  function borrowGivenPosition(
    TimeswapV2PeripheryBorrowGivenPositionParam memory param,
    uint96 durationForward
  ) internal returns (uint256 token0Amount, uint256 token1Amount, bytes memory data, uint160 timeswapV2SqrtInterestRateAfter) {
    data = abi.encode(param.tokenTo, durationForward, param.data);

    // Wrap the long position to ERC1155 wrapper
    // The next logic goes to the timeswapV2TokenMintCallback function
    try ITimeswapV2Token(tokens).mint(
      TimeswapV2TokenMintParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        long0To: param.isLong0 ? param.longTo : address(this),
        long1To: param.isLong0 ? address(this) : param.longTo,
        shortTo: address(this),
        long0Amount: param.isLong0 ? param.positionAmount : 0,
        long1Amount: param.isLong0 ? 0 : param.positionAmount,
        shortAmount: 0,
        data: data
      })
    )
    {} catch (bytes memory reason) {
      data = reason.catchError(PassTokenMintCallbackInfo.selector);
      (timeswapV2SqrtInterestRateAfter, data) = abi.decode(data, (uint160, bytes));
    }

    (token0Amount, token1Amount, data) = abi.decode(data, (uint256, uint256, bytes));
    
  }

  /// @notice the abstract implementation for TimeswapV2TokenMintCallback
  /// @param param params for mintCallBack from TimeswapV2Token
  /// @return data data passed in bytes in the param passed back
  function timeswapV2TokenMintCallback(
    TimeswapV2TokenMintCallbackParam calldata param
  ) external override returns (bytes memory data) {
    address tokenTo;
    uint96 durationForward;
    (tokenTo, durationForward, data) = abi.decode(param.data, (address, uint96, bytes));

    Verify.timeswapV2Token(tokens);

    (, address poolPair) = PoolFactoryLibrary.getWithCheck(optionFactory, poolFactory, param.token0, param.token1);

    data = abi.encode(
      param.token0,
      param.token1,
      tokenTo,
      param.long0Amount != 0,
      param.long0Amount != 0 ? param.long0Amount : param.long1Amount,
      data
    );

    // Call the leverage function to swap short for long0 and/or long1
    // The next logic goes to timeswapV2PoolLeverageChoiceCallback function

    uint256 token0Amount;
    uint256 token1Amount;
    uint160 timeswapV2SqrtInterestRateAfter;
    
    try ITimeswapV2Pool(poolPair).leverage(
        TimeswapV2PoolLeverageParam({
          strike: param.strike,
          maturity: param.maturity,
          long0To: param.long0Amount != 0 ? msg.sender : address(this),
          long1To: param.long0Amount != 0 ? address(this) : msg.sender,
          transaction: TimeswapV2PoolLeverage.GivenSum,
          delta: StrikeConversion.combine(param.long0Amount, param.long1Amount, param.strike, true),
          data: data
        }),
        durationForward
      )
    {} catch (bytes memory reason) {
      data = reason.catchError(PassPoolLeverageCallbackInfo.selector);
      (token0Amount,token1Amount,timeswapV2SqrtInterestRateAfter, data) = abi.decode(data, (uint256, uint256, uint160, bytes));
    }
    // TODO: pass the data back through an error

    data = abi.encode(token0Amount, token1Amount, data);

    revert PassTokenMintCallbackInfo(timeswapV2SqrtInterestRateAfter, data);    

    // The next logic goes back to after the ITimeswapV2Token mint function
  }

  /// @notice the abstract implementation for leverageCallback function
  /// @param param params for  leverageChoiceCallback as mentioned in the TimeswapV2PoolLeverageChoiceCallbackParam struct
  /// @return long0Amount the amount of long0 chosen
  /// @return long1Amount the amount of long1 chosen
  /// @return data data passed as bytes in the param
  function timeswapV2PoolLeverageChoiceCallback(
    TimeswapV2PoolLeverageChoiceCallbackParam calldata param
  ) external override returns (uint256 long0Amount, uint256 long1Amount, bytes memory data) {
    address token0;
    address token1;
    address tokenTo;
    bool isLong0;
    uint256 positionAmount;
    (token0, token1, tokenTo, isLong0, positionAmount, data) = abi.decode(
      param.data,
      (address, address, address, bool, uint256, bytes)
    );

    Verify.timeswapV2Pool(optionFactory, poolFactory, token0, token1);

    uint256 tokenAmount;
    {
      uint256 positionMinted = isLong0
        ? StrikeConversion.turn(param.shortAmount, param.strike, false, true)
        : StrikeConversion.turn(param.shortAmount, param.strike, true, true);
      tokenAmount = positionAmount - positionMinted;
    }
    uint256 tokenAmountNotSwap;
    uint256 tokenAmountSwapped;

    // Ask the inheritor contract how much long0 and long1 to be received from the pool
    (tokenAmountNotSwap, tokenAmountSwapped, data) = timeswapV2PeripheryBorrowGivenPositionChoiceInternal(
      TimeswapV2PeripheryBorrowGivenPositionChoiceInternalParam({
        token0: token0,
        token1: token1,
        strike: param.strike,
        maturity: param.maturity,
        isLong0: isLong0,
        token0Balance: param.long0Balance,
        token1Balance: param.long1Balance,
        tokenAmount: tokenAmount,
        data: data
      })
    );
    uint256 tokenAmountToBeSwap = StrikeConversion.convert(tokenAmountSwapped, param.strike, isLong0, false);

    long0Amount = isLong0 ? tokenAmountNotSwap : tokenAmountToBeSwap;
    long1Amount = isLong0 ? tokenAmountToBeSwap : tokenAmountNotSwap;

    data = abi.encode(token0, token1, tokenTo, isLong0, tokenAmountSwapped, positionAmount, data);

  }

  /// @notice the abstract implementation for leverageCallback function
  /// @param param params for  leverageCallback as mentioned in the TimeswapV2PoolLeverageCallbackParam struct
  /// @return data data passed as bytes in the param
  function timeswapV2PoolLeverageCallback(
    TimeswapV2PoolLeverageCallbackParam calldata param
  ) external override returns (bytes memory data) {
    address token0;
    address token1;
    address tokenTo;
    bool isLong0;
    uint256 tokenAmountSwapped;
    uint256 positionAmount;
    (token0, token1, tokenTo, isLong0, tokenAmountSwapped, positionAmount, data) = abi.decode(
      param.data,
      (address, address, address, bool, uint256, uint256, bytes)
    );

    address optionPair = Verify.timeswapV2Pool(optionFactory, poolFactory, token0, token1);

    data = abi.encode(
      msg.sender,
      token0,
      token1,
      tokenTo,
      isLong0,
      tokenAmountSwapped,
      positionAmount,
      data
    );
    
    // We not mint the long and short
    // The next logic goes to the timeswapV2OptionMintCallback function

    try ITimeswapV2Option(optionPair).mint(
        TimeswapV2OptionMintParam({
          strike: param.strike,
          maturity: param.maturity,
          long0To: isLong0 ? tokens : address(this),
          long1To: isLong0 ? address(this) : tokens,
          shortTo: msg.sender,
          transaction: TimeswapV2OptionMint.GivenShorts,
          amount0: isLong0 ? param.shortAmount : 0,
          amount1: isLong0 ? 0 : param.shortAmount,
          data: data
        })
      )
    {} catch (bytes memory reason) {
      data = reason.catchError(PassOptionMintCallbackInfo.selector);
      data = abi.decode(data, (bytes));
    }

    uint160 timeswapV2SqrtInterestRateAfter = ITimeswapV2Pool(msg.sender).sqrtInterestRate(
      param.strike,
      param.maturity
    );

    revert PassPoolLeverageCallbackInfo(param.long0Amount,param.long1Amount, timeswapV2SqrtInterestRateAfter, data);

    // The next logic goes back to after the ITimeswapV2Pool leverage function
  }

  /// @notice the abstract implementation for TimeswapV2OptionMintCallback
  /// @param param params for mintCallBack from TimeswapV2Option
  /// @return data data passed in bytes in the param passed back
  function timeswapV2OptionMintCallback(
    TimeswapV2OptionMintCallbackParam memory param
  ) external override returns (bytes memory data) {
    address poolPair;
    address token0;
    address token1;
    address tokenTo;
    bool isLong0;
    uint256 tokenAmountSwapped;
    uint256 positionAmount;
    (poolPair, token0, token1, tokenTo, isLong0, tokenAmountSwapped, positionAmount, data) = abi.decode(
      param.data,
      (address, address, address, address, bool, uint256, uint256, bytes)
    );

    Verify.timeswapV2Option(optionFactory, token0, token1);

    if (tokenAmountSwapped != 0) {
      // To achieve the target long0 or long1 received we may need to swap/transform long1 to long0 or long0 to long1 respectively
      data = abi.encode(
        token0,
        token1,
        isLong0 ? param.token0AndLong0Amount : param.token1AndLong1Amount,
        positionAmount,
        data
      );

      // Transform the long received to the required long
      // The next logic goes to timeswapV2OptionSwapCallback function
      try ITimeswapV2Option(msg.sender).swap(
          TimeswapV2OptionSwapParam({
            strike: param.strike,
            maturity: param.maturity,
            tokenTo: tokenTo,
            longTo: tokens,
            isLong0ToLong1: !isLong0,
            transaction: isLong0 ? TimeswapV2OptionSwap.GivenToken0AndLong0 : TimeswapV2OptionSwap.GivenToken1AndLong1,
            amount: tokenAmountSwapped,
            data: data
          })
        )
      {} catch (bytes memory reason) {
        data = reason.catchError(PassOptionSwapCallbackInfo.selector);
        data = abi.decode(data, (bytes));
      }
    }
    // There is no need to transform long0 to long1 or long1 to long0
    // Ask the inheritor contract to transfer the required ERC20 to the option pair contract
    else
      data = timeswapV2PeripheryBorrowGivenPositionInternal(
        TimeswapV2PeripheryBorrowGivenPositionInternalParam({
          optionPair: msg.sender,
          token0: token0,
          token1: token1,
          strike: param.strike,
          maturity: param.maturity,
          isLong0: isLong0,
          token0Amount: isLong0 ? param.token0AndLong0Amount : 0,
          token1Amount: isLong0 ? 0 : param.token1AndLong1Amount,
          positionAmount: positionAmount,
          data: data
        })
      );

    // The next logic goes back to after the TimeswapV2Option mint was called
    revert PassOptionMintCallbackInfo(data);
  }

  /// @notice the abstract implementation for TimeswapV2OptionSwapCallback
  /// @param param params for swapCallBack from TimeswapV2Option
  /// @return data data passed in bytes in the param passed back
  function timeswapV2OptionSwapCallback(
    TimeswapV2OptionSwapCallbackParam calldata param
  ) external override returns (bytes memory data) {
    address token0;
    address token1;
    uint256 depositAmount;
    uint256 positionAmount;
    (token0, token1, depositAmount, positionAmount, data) = abi.decode(
      param.data,
      (address, address, uint256, uint256, bytes)
    );

    Verify.timeswapV2Option(optionFactory, token0, token1);

    // Ask the inheritor contract to transfer the required ERC20 to the option pair contract
    data = timeswapV2PeripheryBorrowGivenPositionInternal(
      TimeswapV2PeripheryBorrowGivenPositionInternalParam({
        optionPair: msg.sender,
        token0: token0,
        token1: token1,
        strike: param.strike,
        maturity: param.maturity,
        isLong0: !param.isLong0ToLong1,
        token0Amount: param.token0AndLong0Amount + (param.isLong0ToLong1 ? 0 : depositAmount),
        token1Amount: param.token1AndLong1Amount + (param.isLong0ToLong1 ? depositAmount : 0),
        positionAmount: positionAmount,
        data: data
      })
    );
    
    revert PassOptionSwapCallbackInfo(data);

    // The next logic goes back to after the TimeswapV2Option swap function was called
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2BorrowGivenPosition
  /// @param param params for calling the implementation specfic borrowGivenPosition to be overriden
  /// @return tokenAmountToNotSwap tokenAmount not swapp. Is token0 if isLong0 is true, else is token1 if isLong0 is fales.
  /// @return tokenAmountSwapped tokenAmount swapped. Is token0 if isLong0 is true, else is token1 if isLong0 is false.
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryBorrowGivenPositionChoiceInternal(
    TimeswapV2PeripheryBorrowGivenPositionChoiceInternalParam memory param
  ) internal virtual returns (uint256 tokenAmountToNotSwap, uint256 tokenAmountSwapped, bytes memory data);

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2BorrowGivenPosition
  /// @param param params for calling the implementation specfic borrowGivenPosition to be overriden
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryBorrowGivenPositionInternal(
    TimeswapV2PeripheryBorrowGivenPositionInternalParam memory param
  ) internal virtual returns (bytes memory data);
}
