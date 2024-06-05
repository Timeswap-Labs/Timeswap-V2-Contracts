// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

import {CatchError} from "@timeswap-labs/v2-library/contracts/CatchError.sol";

import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";

import {TimeswapV2OptionBurnParam} from "@timeswap-labs/v2-option/contracts/structs/Param.sol";

import {TimeswapV2OptionMint, TimeswapV2OptionBurn, TimeswapV2OptionSwap} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {TimeswapV2PoolLeverageParam} from "@timeswap-labs/v2-pool/contracts/structs/Param.sol";
import {TimeswapV2PoolLeverageChoiceCallbackParam, TimeswapV2PoolLeverageCallbackParam} from "@timeswap-labs/v2-pool/contracts/structs/CallbackParam.sol";

import {TimeswapV2PoolLeverage} from "@timeswap-labs/v2-pool/contracts/enums/Transaction.sol";

import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenBurnParam} from "@timeswap-labs/v2-token/contracts/structs/Param.sol";
import {TimeswapV2TokenBurnCallbackParam} from "@timeswap-labs/v2-token/contracts/structs/CallbackParam.sol";

import {ITimeswapV2PeripheryQuoterCloseLendGivenPosition} from "../interfaces/lens/ITimeswapV2PeripheryQuoterCloseLendGivenPosition.sol";

import {TimeswapV2PeripheryCloseLendGivenPositionParam} from "../structs/Param.sol";
import {TimeswapV2PeripheryCloseLendGivenPositionChoiceInternalParam} from "../structs/InternalParam.sol";

import {Verify} from "../libraries/Verify.sol";

abstract contract TimeswapV2PeripheryQuoterCloseLendGivenPosition is
  ITimeswapV2PeripheryQuoterCloseLendGivenPosition,
  ERC1155Receiver
{
  using CatchError for bytes;

  /* ===== MODEL ===== */
  /// @inheritdoc ITimeswapV2PeripheryQuoterCloseLendGivenPosition
  address public immutable override optionFactory;
  /// @inheritdoc ITimeswapV2PeripheryQuoterCloseLendGivenPosition
  address public immutable override poolFactory;
  /// @inheritdoc ITimeswapV2PeripheryQuoterCloseLendGivenPosition
  address public immutable override tokens;

  /* ===== INIT ===== */

  constructor(address chosenOptionFactory, address chosenPoolFactory, address chosenTokens) {
    optionFactory = chosenOptionFactory;
    poolFactory = chosenPoolFactory;
    tokens = chosenTokens;
  }

  /// @notice the abstract implementation for closeLendGivenPosition function
  /// @param param params for  closeLendGivenPosition as mentioned in the TimeswapV2PeripheryCloseLendGivenPositionParam struct
  /// @param durationForward the amount of seconds moved forward
  /// @return token0Amount resulting token0 amount
  /// @return token1Amount resulting token1 amount
  /// @return data data passed as bytes in the param
  /// @return timeswapV2SqrtInterestRateAfter the new sqrt interest rate after this transaction
  function closeLendGivenPosition(
    TimeswapV2PeripheryCloseLendGivenPositionParam memory param,
    uint96 durationForward
  )
    internal
    returns (uint256 token0Amount, uint256 token1Amount, bytes memory data, uint160 timeswapV2SqrtInterestRateAfter)
  {
    data = abi.encode(param.token0To, param.token1To, param.positionAmount, durationForward, param.data);

    try
      ITimeswapV2Token(tokens).burn(
        TimeswapV2TokenBurnParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          long0To: address(this),
          long1To: address(this),
          shortTo: address(this),
          long0Amount: 0,
          long1Amount: 0,
          shortAmount: param.positionAmount,
          data: data
        })
      )
    {} catch (bytes memory reason) {
      data = reason.catchError(PassTokenBurnCallbackInfo.selector);
      (timeswapV2SqrtInterestRateAfter, token0Amount, token1Amount, data) = abi.decode(
        data,
        (uint160, uint256, uint256, bytes)
      );
    }
  }

  /// @notice the abstract implementation for token burn function
  /// @param param params for  timeswapV2TokenBurnCallback
  /// @return data data passed as bytes in the param
  function timeswapV2TokenBurnCallback(
    TimeswapV2TokenBurnCallbackParam calldata param
  ) external returns (bytes memory data) {
    address token0To;
    address token1To;
    uint256 positionAmount;
    uint96 durationForward;
    (token0To, token1To, positionAmount, durationForward, data) = abi.decode(
      param.data,
      (address, address, uint256, uint96, bytes)
    );

    (, address poolPair) = PoolFactoryLibrary.getWithCheck(optionFactory, poolFactory, param.token0, param.token1);

    data = abi.encode(param.token0, param.token1, token0To, token1To, positionAmount, data);

    try
      ITimeswapV2Pool(poolPair).leverage(
        TimeswapV2PoolLeverageParam({
          strike: param.strike,
          maturity: param.maturity,
          long0To: address(this),
          long1To: address(this),
          transaction: TimeswapV2PoolLeverage.GivenSum,
          delta: positionAmount,
          data: data
        }),
        durationForward
      )
    {} catch (bytes memory reason) {
      data = reason.catchError(PassPoolLeverageCallbackInfo.selector);

      uint160 timeswapV2SqrtInterestRateAfter;
      uint256 token0Amount;
      uint256 token1Amount;
      (timeswapV2SqrtInterestRateAfter, token0Amount, token1Amount, data) = abi.decode(
        data,
        (uint160, uint256, uint256, bytes)
      );

      revert PassTokenBurnCallbackInfo(timeswapV2SqrtInterestRateAfter, token0Amount, token1Amount, data);
    }
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
    address token0To;
    address token1To;
    uint256 positionAmount;
    (token0, token1, token0To, token1To, positionAmount, data) = abi.decode(
      param.data,
      (address, address, address, address, uint256, bytes)
    );

    Verify.timeswapV2Pool(optionFactory, poolFactory, token0, token1);

    (long0Amount, long1Amount, data) = timeswapV2PeripheryCloseLendGivenPositionChoiceInternal(
      TimeswapV2PeripheryCloseLendGivenPositionChoiceInternalParam({
        token0: token0,
        token1: token1,
        strike: param.strike,
        maturity: param.maturity,
        token0Balance: param.long0Balance,
        token1Balance: param.long1Balance,
        tokenAmount: param.longAmount,
        data: data
      })
    );

    data = abi.encode(token0, token1, token0To, token1To, positionAmount, data);
  }

  /// @notice the abstract implementation for leverageCallback function
  /// @param param params for  leverageCallback as mentioned in the TimeswapV2PoolLeverageCallbackParam struct
  /// @return data data passed as bytes in the param
  function timeswapV2PoolLeverageCallback(
    TimeswapV2PoolLeverageCallbackParam calldata param
  ) external override returns (bytes memory data) {
    address token0;
    address token1;
    address token0To;
    address token1To;
    uint256 positionAmount;
    (token0, token1, token0To, token1To, positionAmount, data) = abi.decode(
      param.data,
      (address, address, address, address, uint256, bytes)
    );

    address optionPair = Verify.timeswapV2Pool(optionFactory, poolFactory, token0, token1);

    (, , uint256 shortAmountBurnt, ) = ITimeswapV2Option(optionPair).burn(
      TimeswapV2OptionBurnParam({
        strike: param.strike,
        maturity: param.maturity,
        token0To: token0To,
        token1To: token1To,
        transaction: TimeswapV2OptionBurn.GivenTokensAndLongs,
        amount0: param.long0Amount,
        amount1: param.long1Amount,
        data: bytes("")
      })
    );

    ITimeswapV2Option(optionPair).transferPosition(
      param.strike,
      param.maturity,
      msg.sender,
      TimeswapV2OptionPosition.Short,
      positionAmount - shortAmountBurnt
    );

    uint160 timeswapV2SqrtInterestRateAfter = ITimeswapV2Pool(msg.sender).sqrtInterestRate(
      param.strike,
      param.maturity
    );

    revert PassPoolLeverageCallbackInfo(timeswapV2SqrtInterestRateAfter, param.long0Amount, param.long1Amount, data);
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2CloseLendGivenPosition
  /// @param param params for calling the implementation specfic closeLendGivenPosition to be overriden
  /// @return long0Amount the amount of long0 returned
  /// @return long1Amount the amount of long1 returned
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryCloseLendGivenPositionChoiceInternal(
    TimeswapV2PeripheryCloseLendGivenPositionChoiceInternalParam memory param
  ) internal virtual returns (uint256 long0Amount, uint256 long1Amount, bytes memory data);
}
