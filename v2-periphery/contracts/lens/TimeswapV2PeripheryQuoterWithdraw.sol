// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {CatchError} from "@timeswap-labs/v2-library/contracts/CatchError.sol";

import {ITimeswapV2OptionFactory} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2OptionFactory.sol";
import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";

import {OptionFactoryLibrary} from "@timeswap-labs/v2-option/contracts/libraries/OptionFactory.sol";

import {TimeswapV2OptionMintParam, TimeswapV2OptionCollectParam} from "@timeswap-labs/v2-option/contracts/structs/Param.sol";
import {TimeswapV2OptionMintCallbackParam} from "@timeswap-labs/v2-option/contracts/structs/CallbackParam.sol";

import {TimeswapV2OptionMint, TimeswapV2OptionCollect} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2PoolFactory} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2PoolFactory.sol";
import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenBurnParam} from "@timeswap-labs/v2-token/contracts/structs/Param.sol";
import {TimeswapV2TokenBurnCallbackParam} from "@timeswap-labs/v2-token/contracts/structs/CallbackParam.sol";

import {TimeswapV2PeripheryWithdrawParam} from "../structs/Param.sol";

import {ITimeswapV2PeripheryQuoterWithdraw} from "../interfaces/lens/ITimeswapV2PeripheryQuoterWithdraw.sol";
import {Verify} from "../libraries/Verify.sol";

/// @title Abstract contract which specifies functions that are required for  withdraw which are to be inherited for a specific DEX/Aggregator implementation
abstract contract TimeswapV2PeripheryQuoterWithdraw is ITimeswapV2PeripheryQuoterWithdraw, ERC1155Receiver {
  using CatchError for bytes;

  /* ===== MODEL ===== */
  /// @inheritdoc ITimeswapV2PeripheryQuoterWithdraw
  address public immutable override optionFactory;
  /// @inheritdoc ITimeswapV2PeripheryQuoterWithdraw
  address public immutable override tokens;

  /* ===== INIT ===== */

  constructor(address chosenOptionFactory, address chosenTokens) {
    optionFactory = chosenOptionFactory;
    tokens = chosenTokens;
  }

  /// @notice the abstract implementation for withdraw function
  /// @param param params for  withdraw as mentioned in the TimeswapV2PeripheryWithdrawParam struct
  /// @return token0Amount is the token0Amount recieved
  /// @return token1Amount is the token0Amount recieved
  function withdraw(
    TimeswapV2PeripheryWithdrawParam memory param
  ) internal returns (uint256 token0Amount, uint256 token1Amount) {
    bytes memory data = abi.encode(param.token0To, param.token1To, param.positionAmount);

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
      (token0Amount, token1Amount) = abi.decode(data, (uint256, uint256));
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
    (token0To, token1To, positionAmount) = abi.decode(param.data, (address, address, uint256));

    address optionPair = OptionFactoryLibrary.getWithCheck(optionFactory, param.token0, param.token1);

    (uint256 token0Amount, uint256 token1Amount, , ) = ITimeswapV2Option(optionPair).collect(
      TimeswapV2OptionCollectParam({
        strike: param.strike,
        maturity: param.maturity,
        token0To: token0To,
        token1To: token1To,
        transaction: TimeswapV2OptionCollect.GivenShort,
        amount: positionAmount,
        data: bytes("")
      })
    );

    data = bytes("");

    revert PassTokenBurnCallbackInfo(token0Amount, token1Amount);
  }
}
