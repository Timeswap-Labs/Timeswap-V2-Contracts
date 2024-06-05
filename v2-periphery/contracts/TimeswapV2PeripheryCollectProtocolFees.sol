// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {StrikeConversion} from "@timeswap-labs/v2-library/contracts/StrikeConversion.sol";

import {Ownership} from "@timeswap-labs/v2-library/contracts/Ownership.sol";
import {Error} from "@timeswap-labs/v2-library/contracts/Error.sol";

import {ITimeswapV2OptionFactory} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2OptionFactory.sol";
import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";

import {OptionFactoryLibrary} from "@timeswap-labs/v2-option/contracts/libraries/OptionFactory.sol";

import {TimeswapV2OptionBurnParam} from "@timeswap-labs/v2-option/contracts/structs/Param.sol";

import {TimeswapV2OptionBurn} from "@timeswap-labs/v2-option/contracts/enums/Transaction.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {OwnableTwoSteps} from "@timeswap-labs/v2-pool/contracts/base/OwnableTwoSteps.sol";

import {IOwnableTwoSteps} from "@timeswap-labs/v2-pool/contracts/interfaces/IOwnableTwoSteps.sol";
import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";

import {TimeswapV2PoolCollectProtocolFeesParam} from "@timeswap-labs/v2-pool/contracts/structs/Param.sol";

import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";

import {ITimeswapV2Token} from "@timeswap-labs/v2-token/contracts/interfaces/ITimeswapV2Token.sol";

import {TimeswapV2TokenMintParam} from "@timeswap-labs/v2-token/contracts/structs/Param.sol";
import {TimeswapV2TokenMintCallbackParam} from "@timeswap-labs/v2-token/contracts/structs/CallbackParam.sol";

import {ITimeswapV2PeripheryCollectProtocolFees} from "./interfaces/ITimeswapV2PeripheryCollectProtocolFees.sol";

import {TimeswapV2PeripheryCollectProtocolFeesParam} from "./structs/Param.sol";
import {TimeswapV2PeripheryCollectProtocolFeesExcessLongChoiceInternalParam} from "./structs/InternalParam.sol";
import {Verify} from "./libraries/Verify.sol";
import {Math} from "@timeswap-labs/v2-library/contracts/Math.sol";

/// @title Abstract contract which specifies functions that are required for  collect protocol fees which are to be inherited for a specific DEX/Aggregator implementation
abstract contract TimeswapV2PeripheryCollectProtocolFees is ITimeswapV2PeripheryCollectProtocolFees, OwnableTwoSteps {
  using Ownership for address;
  using Math for uint256;
  /* ===== MODEL ===== */
  /// @inheritdoc ITimeswapV2PeripheryCollectProtocolFees
  address public immutable override optionFactory;
  /// @inheritdoc ITimeswapV2PeripheryCollectProtocolFees
  address public immutable override poolFactory;
  /// @inheritdoc ITimeswapV2PeripheryCollectProtocolFees
  address public immutable override tokens;

  /* ===== INIT ===== */

  constructor(
    address chosenOwner,
    address chosenOptionFactory,
    address chosenPoolFactory,
    address chosenTokens
  ) OwnableTwoSteps(chosenOwner) {
    optionFactory = chosenOptionFactory;
    poolFactory = chosenPoolFactory;
    tokens = chosenTokens;
  }

  ///@notice function to set the owner
  ///@param chosenPendingOwner address of the owner to be chosen
  function set(address chosenPendingOwner) external {
    Ownership.checkIfOwner(owner);
    IOwnableTwoSteps(poolFactory).setPendingOwner(chosenPendingOwner);
  }

  ///@notice function to accept the owner
  function accept() external {
    Ownership.checkIfOwner(owner);
    IOwnableTwoSteps(poolFactory).acceptOwner();
  }

  /// @notice the abstract implementation for collect protocol fees function
  /// @notice can only be called by the owner
  /// @param param params for  collectProtocolFees as mentioned in the TimeswapV2PeripheryCollectProtocolFeesParam struct
  /// @return token0Amount the resulting token0Amount
  /// @return token1Amount the resulting token1Amount
  /// @return excessLong0Amount the resulting exceessLong0Amount
  /// @return excessLong1Amount the resulting excessLong1Amount
  /// @return excessShortAmount the resulting excessShortAmount
  /// @return data data passed as bytes in the param
  function collectProtocolFees(
    TimeswapV2PeripheryCollectProtocolFeesParam memory param
  )
    internal
    returns (
      uint256 token0Amount,
      uint256 token1Amount,
      uint256 excessLong0Amount,
      uint256 excessLong1Amount,
      uint256 excessShortAmount,
      bytes memory data
    )
  {
    Ownership.checkIfOwner(owner);

    (address optionPair, address poolPair) = PoolFactoryLibrary.getWithCheck(
      optionFactory,
      poolFactory,
      param.token0,
      param.token1
    );

    // collect the protocol fees from a Timeswap V2 pool
    uint256 shortAmount;
    (token0Amount, token1Amount, shortAmount) = ITimeswapV2Pool(poolPair).collectProtocolFees(
      TimeswapV2PoolCollectProtocolFeesParam({
        strike: param.strike,
        maturity: param.maturity,
        long0To: address(this),
        long1To: address(this),
        shortTo: address(this),
        long0Requested: param.long0Requested,
        long1Requested: param.long1Requested,
        shortRequested: param.shortRequested
      })
    );

    uint256 longAmount = StrikeConversion.combine(token0Amount, token1Amount, param.strike, true);

    if (shortAmount >= longAmount) {
      // There are more short than long, thus burning any matching amount we will have some short remaining
      ITimeswapV2Option(optionPair).burn(
        TimeswapV2OptionBurnParam({
          strike: param.strike,
          maturity: param.maturity,
          token0To: param.token0To,
          token1To: param.token1To,
          transaction: TimeswapV2OptionBurn.GivenTokensAndLongs,
          amount0: token0Amount,
          amount1: token1Amount,
          data: bytes("")
        })
      );

      excessShortAmount = shortAmount.unsafeSub(longAmount);

      // wrap the remaining short as an ERC1155
      // The next logic goes to timeswapV2TokenMintCallback function
      if (excessShortAmount != 0)
        ITimeswapV2Token(tokens).mint(
          TimeswapV2TokenMintParam({
            token0: param.token0,
            token1: param.token1,
            strike: param.strike,
            maturity: param.maturity,
            long0To: address(this),
            long1To: address(this),
            shortTo: param.excessShortTo,
            long0Amount: uint256(0),
            long1Amount: uint256(0),
            shortAmount: excessShortAmount,
            data: bytes("")
          })
        );

      data = param.data;
    } else {
      // There are more long than short, thus burning any matching amount we will have some long remaining
      excessLong0Amount = token0Amount;
      excessLong1Amount = token1Amount;

      // Ask the inheritor contract how much long0 and long1 to burn with short
      (token0Amount, token1Amount, data) = timeswapV2PeripheryCollectProtocolFeesExcessLongChoiceInternal(
        TimeswapV2PeripheryCollectProtocolFeesExcessLongChoiceInternalParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          token0Balance: token0Amount,
          token1Balance: token1Amount,
          tokenAmount: shortAmount,
          data: param.data
        })
      );

      (, , uint256 shortAmountBurnt, ) = ITimeswapV2Option(optionPair).burn(
        TimeswapV2OptionBurnParam({
          strike: param.strike,
          maturity: param.maturity,
          token0To: param.token0To,
          token1To: param.token1To,
          transaction: TimeswapV2OptionBurn.GivenTokensAndLongs,
          amount0: token0Amount,
          amount1: token1Amount,
          data: bytes("")
        })
      );

      Error.checkEnough(shortAmountBurnt, shortAmount);

      excessLong0Amount -= token0Amount;
      excessLong1Amount -= token1Amount;

      // Wrap remaining long as ERC1155
      // The next logic goes to timeswapV2TokenMintCallback function
      ITimeswapV2Token(tokens).mint(
        TimeswapV2TokenMintParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          long0To: param.excessLong0To,
          long1To: param.excessLong1To,
          shortTo: address(this),
          long0Amount: excessLong0Amount,
          long1Amount: excessLong1Amount,
          shortAmount: uint256(0),
          data: bytes("")
        })
      );
    }
  }

  /// @notice the abstract implementation for TimeswapV2TokenMintCallback
  /// @param param params for mintCallBack from TimeswapV2Token
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

    // The next logic goes to after the timeswapV2Token mint was called
  }

  /// @notice the implementation which is to be overriden for DEX/Aggregator specific logic for TimeswapV2CollectProtocolFeesExcessLongChoice
  /// @param param params for calling the implementation specfic collectProtocolFeesExcessLongChoice to be overriden
  /// @return token0Amount resulting token0 amount
  /// @return token1Amount resulting token1 amount
  /// @return data data passed in bytes in the param passed back
  function timeswapV2PeripheryCollectProtocolFeesExcessLongChoiceInternal(
    TimeswapV2PeripheryCollectProtocolFeesExcessLongChoiceInternalParam memory param
  ) internal virtual returns (uint256 token0Amount, uint256 token1Amount, bytes memory data);
}
