// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Error} from "@timeswap-labs/v2-library/contracts/Error.sol";

import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2PeripheryQuoterBorrowGivenPosition} from "@timeswap-labs/v2-periphery/contracts/lens/TimeswapV2PeripheryQuoterBorrowGivenPosition.sol";

import {TimeswapV2PeripheryBorrowGivenPositionParam} from "@timeswap-labs/v2-periphery/contracts/structs/Param.sol";
import {TimeswapV2PeripheryBorrowGivenPositionChoiceInternalParam, TimeswapV2PeripheryBorrowGivenPositionInternalParam} from "@timeswap-labs/v2-periphery/contracts/structs/InternalParam.sol";

import {ITimeswapV2PeripheryNoDexQuoterBorrowGivenPosition} from "../interfaces/lens/ITimeswapV2PeripheryNoDexQuoterBorrowGivenPosition.sol";

import {TimeswapV2PeripheryNoDexQuoterBorrowGivenPositionParam} from "../structs/lens/QuoterParam.sol";

// import {NativeImmutableState, NativeWithdraws, NativePayments} from "../base/Native.sol";

import {Multicall} from "../base/Multicall.sol";
import {Math} from "@timeswap-labs/v2-library/contracts/Math.sol";

/// @title Capable of borrowing a given amount of collateral from a given position
/// @author Timeswap Labs
contract TimeswapV2PeripheryNoDexQuoterBorrowGivenPosition is
  ITimeswapV2PeripheryNoDexQuoterBorrowGivenPosition,
  TimeswapV2PeripheryQuoterBorrowGivenPosition,
  Multicall
{
  using Math for uint256;
  using SafeERC20 for IERC20;

  constructor(
    address chosenOptionFactory,
    address chosenPoolFactory,
    address chosenTokens
  )
    TimeswapV2PeripheryQuoterBorrowGivenPosition(chosenOptionFactory, chosenPoolFactory, chosenTokens)
  {}

  /// @inheritdoc ITimeswapV2PeripheryNoDexQuoterBorrowGivenPosition
  function borrowGivenPosition(
    TimeswapV2PeripheryNoDexQuoterBorrowGivenPositionParam calldata param,
    uint96 durationForward
  ) external returns (uint256 tokenAmount, uint160 timeswapV2SqrtInterestRateAfter) {
    // if (param.deadline < block.timestamp) Error.deadlineReached(param.deadline);

    bytes memory data = abi.encode(msg.sender, param.isToken0);

    (, , data, timeswapV2SqrtInterestRateAfter) = borrowGivenPosition(
      TimeswapV2PeripheryBorrowGivenPositionParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        tokenTo: param.isToken0 == param.isLong0 ? address(this) : param.tokenTo,
        longTo: param.longTo,
        isLong0: param.isLong0,
        positionAmount: param.positionAmount,
        data: data
      }),
      durationForward
    );

    tokenAmount = abi.decode(data, (uint256));

    // if (tokenAmount < param.minTokenAmount) revert MinTokenReached(tokenAmount, param.minTokenAmount);

    // emit BorrowGivenPosition(
    //   param.token0,
    //   param.token1,
    //   param.strike,
    //   param.maturity,
    //   msg.sender,
    //   param.tokenTo,
    //   param.longTo,
    //   param.isToken0,
    //   param.isLong0,
    //   tokenAmount,
    //   param.positionAmount
    // );
  }

  function timeswapV2PeripheryBorrowGivenPositionChoiceInternal(
    TimeswapV2PeripheryBorrowGivenPositionChoiceInternalParam memory param
  ) internal pure override returns (uint256 tokenAmountToNotSwap, uint256 tokenAmountSwapped, bytes memory data) {
    (, bool isToken0) = abi.decode(param.data, (address, bool));
    tokenAmountToNotSwap = param.isLong0 == isToken0 ? param.tokenAmount : 0;
    tokenAmountSwapped = param.isLong0 == isToken0 ? 0 : param.tokenAmount;
    data = param.data;
  }

  function timeswapV2PeripheryBorrowGivenPositionInternal(
    TimeswapV2PeripheryBorrowGivenPositionInternalParam memory param
  ) internal override returns (bytes memory data) {
    (, bool isToken0) = abi.decode(param.data, (address, bool));

    // pay(
    //   param.isLong0 ? param.token0 : param.token1,
    //   msgSender,
    //   param.optionPair,
    //   param.isLong0 ? param.token0Amount : param.token1Amount
    // );

    data = abi.encode(isToken0 ? param.token0Amount : param.token1Amount);
  }
}
