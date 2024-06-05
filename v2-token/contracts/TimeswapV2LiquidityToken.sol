// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";
import {OptionFactoryLibrary} from "@timeswap-labs/v2-option/contracts/libraries/OptionFactory.sol";
import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {ITimeswapV2Pool} from "@timeswap-labs/v2-pool/contracts/interfaces/ITimeswapV2Pool.sol";
import {PoolFactoryLibrary} from "@timeswap-labs/v2-pool/contracts/libraries/PoolFactory.sol";
import {ReentrancyGuard} from "@timeswap-labs/v2-pool/contracts/libraries/ReentrancyGuard.sol";

import {TimeswapV2PoolCollectTransactionFeesAndShortReturnedParam} from "@timeswap-labs/v2-pool/contracts/structs/Param.sol";

import {ITimeswapV2LiquidityToken} from "./interfaces/ITimeswapV2LiquidityToken.sol";

import {ITimeswapV2LiquidityTokenMintCallback} from "./interfaces/callbacks/ITimeswapV2LiquidityTokenMintCallback.sol";
import {ITimeswapV2LiquidityTokenBurnCallback} from "./interfaces/callbacks/ITimeswapV2LiquidityTokenBurnCallback.sol";
import {ITimeswapV2LiquidityTokenCollectCallback} from "./interfaces/callbacks/ITimeswapV2LiquidityTokenCollectCallback.sol";

import {ERC1155Enumerable} from "./base/ERC1155Enumerable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import {TimeswapV2LiquidityTokenPosition, PositionLibrary} from "./structs/Position.sol";
import {FeesPosition, FeesPositionLibrary} from "./structs/FeesPosition.sol";
import {PoolPosition, PoolPositionLibrary} from "./structs/PoolPosition.sol";
import {TimeswapV2LiquidityTokenMintParam, TimeswapV2LiquidityTokenBurnParam, TimeswapV2LiquidityTokenCollectParam, ParamLibrary} from "./structs/Param.sol";
import {TimeswapV2LiquidityTokenMintCallbackParam, TimeswapV2LiquidityTokenBurnCallbackParam, TimeswapV2LiquidityTokenCollectCallbackParam} from "./structs/CallbackParam.sol";
import {Error} from "@timeswap-labs/v2-library/contracts/Error.sol";

/// @title An implementation for TS-V2 liquidity token system
/// @author Timeswap Labs
contract TimeswapV2LiquidityToken is ITimeswapV2LiquidityToken, ERC1155Enumerable {
  using ReentrancyGuard for uint96;

  using PositionLibrary for TimeswapV2LiquidityTokenPosition;
  using FeesPositionLibrary for FeesPosition;
  using PoolPositionLibrary for PoolPosition;

  address public immutable optionFactory;
  address public immutable poolFactory;

  constructor(
    address chosenOptionFactory,
    address chosenPoolFactory,
    string memory uri
  ) ERC1155("Timeswap V2 Liquidity Token") {
    optionFactory = chosenOptionFactory;
    poolFactory = chosenPoolFactory;
    _setURI(uri);
  }

  mapping(bytes32 => uint96) private reentrancyGuards;

  mapping(uint256 => TimeswapV2LiquidityTokenPosition) private _timeswapV2LiquidityTokenPositions;

  mapping(bytes32 => uint256) private _timeswapV2LiquidityTokenPositionIds;

  mapping(uint256 => PoolPosition) private _poolPositions;

  mapping(uint256 => mapping(address => FeesPosition)) private _feesPositions;

  mapping(uint256 => uint256) private _totalSupply;

  uint256 private counter;

  function changeInteractedIfNecessary(bytes32 key) private {
    if (reentrancyGuards[key] == ReentrancyGuard.NOT_INTERACTED) reentrancyGuards[key] = ReentrancyGuard.NOT_ENTERED;
  }

  /// @dev internal function to start the reentrancy guard
  function raiseGuard(bytes32 key) private {
    reentrancyGuards[key].check();
    reentrancyGuards[key] = ReentrancyGuard.ENTERED;
  }

  /// @dev internal function to end the reentrancy guard
  function lowerGuard(bytes32 key) private {
    reentrancyGuards[key] = ReentrancyGuard.NOT_ENTERED;
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function positionOf(
    address owner,
    TimeswapV2LiquidityTokenPosition calldata timeswapV2LiquidityTokenPosition
  ) external view override returns (uint256 amount) {
    amount = balanceOf(owner, _timeswapV2LiquidityTokenPositionIds[timeswapV2LiquidityTokenPosition.toKey()]);
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function feesEarnedAndShortReturnedGrowth(
    TimeswapV2LiquidityTokenPosition calldata timeswapV2LiquidityTokenPosition
  )
    external
    view
    override
    returns (uint256 long0FeeGrowth, uint256 long1FeeGrowth, uint256 shortFeeGrowth, uint256 shortReturnedGrowth)
  {
    uint256 id = _timeswapV2LiquidityTokenPositionIds[timeswapV2LiquidityTokenPosition.toKey()];

    if (_totalSupply[id] == 0) {
      PoolPosition memory poolPosition = _poolPositions[id];

      long0FeeGrowth = poolPosition.long0FeeGrowth;
      long1FeeGrowth = poolPosition.long1FeeGrowth;
      shortFeeGrowth = poolPosition.shortFeeGrowth;
      shortReturnedGrowth = poolPosition.shortReturnedGrowth;
    } else {
      (, address poolPair) = PoolFactoryLibrary.getWithCheck(
        optionFactory,
        poolFactory,
        timeswapV2LiquidityTokenPosition.token0,
        timeswapV2LiquidityTokenPosition.token1
      );

      (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned) = ITimeswapV2Pool(poolPair)
        .feesEarnedAndShortReturnedOf(
          timeswapV2LiquidityTokenPosition.strike,
          timeswapV2LiquidityTokenPosition.maturity,
          address(this)
        );

      (long0FeeGrowth, long1FeeGrowth, shortFeeGrowth, shortReturnedGrowth) = _poolPositions[id]
        .getFeesAndShortReturnedGrowth(uint160(_totalSupply[id]), long0Fees, long1Fees, shortFees, shortReturned);
    }
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function feesEarnedAndShortReturnedGrowth(
    TimeswapV2LiquidityTokenPosition calldata timeswapV2LiquidityTokenPosition,
    uint96 durationForward
  )
    external
    view
    override
    returns (uint256 long0FeeGrowth, uint256 long1FeeGrowth, uint256 shortFeeGrowth, uint256 shortReturnedGrowth)
  {
    uint256 id = _timeswapV2LiquidityTokenPositionIds[timeswapV2LiquidityTokenPosition.toKey()];

    if (_totalSupply[id] == 0) {
      PoolPosition memory poolPosition = _poolPositions[id];

      long0FeeGrowth = poolPosition.long0FeeGrowth;
      long1FeeGrowth = poolPosition.long1FeeGrowth;
      shortFeeGrowth = poolPosition.shortFeeGrowth;
      shortReturnedGrowth = poolPosition.shortReturnedGrowth;
    } else {
      (, address poolPair) = PoolFactoryLibrary.getWithCheck(
        optionFactory,
        poolFactory,
        timeswapV2LiquidityTokenPosition.token0,
        timeswapV2LiquidityTokenPosition.token1
      );

      (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned) = ITimeswapV2Pool(poolPair)
        .feesEarnedAndShortReturnedOf(
          timeswapV2LiquidityTokenPosition.strike,
          timeswapV2LiquidityTokenPosition.maturity,
          address(this),
          durationForward
        );

      (long0FeeGrowth, long1FeeGrowth, shortFeeGrowth, shortReturnedGrowth) = _poolPositions[id]
        .getFeesAndShortReturnedGrowth(uint160(_totalSupply[id]), long0Fees, long1Fees, shortFees, shortReturned);
    }
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function feesEarnedAndShortReturnedOf(
    address owner,
    TimeswapV2LiquidityTokenPosition calldata timeswapV2LiquidityTokenPosition
  ) external view returns (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned) {
    uint256 id = _timeswapV2LiquidityTokenPositionIds[timeswapV2LiquidityTokenPosition.toKey()];

    if (_totalSupply[id] == 0) {
      FeesPosition memory feesPosition = _feesPositions[id][owner];

      long0Fees = feesPosition.long0Fees;
      long1Fees = feesPosition.long1Fees;
      shortFees = feesPosition.shortFees;
      shortReturned = feesPosition.shortReturned;
    } else {
      (, address poolPair) = PoolFactoryLibrary.getWithCheck(
        optionFactory,
        poolFactory,
        timeswapV2LiquidityTokenPosition.token0,
        timeswapV2LiquidityTokenPosition.token1
      );

      (long0Fees, long1Fees, shortFees, shortReturned) = ITimeswapV2Pool(poolPair).feesEarnedAndShortReturnedOf(
        timeswapV2LiquidityTokenPosition.strike,
        timeswapV2LiquidityTokenPosition.maturity,
        address(this)
      );

      (
        uint256 long0FeeGrowth,
        uint256 long1FeeGrowth,
        uint256 shortFeeGrowth,
        uint256 shortReturnedGrowth
      ) = _poolPositions[id].getFeesAndShortReturnedGrowth(
          uint160(_totalSupply[id]),
          long0Fees,
          long1Fees,
          shortFees,
          shortReturned
        );

      FeesPosition memory feesPosition = _feesPositions[id][owner];

      (long0Fees, long1Fees, shortFees, shortReturned) = feesPosition.feesEarnedAndShortReturnedOf(
        uint160(balanceOf(owner, id)),
        long0FeeGrowth,
        long1FeeGrowth,
        shortFeeGrowth,
        shortReturnedGrowth
      );
    }
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function feesEarnedAndShortReturnedOf(
    address owner,
    TimeswapV2LiquidityTokenPosition calldata timeswapV2LiquidityTokenPosition,
    uint96 durationForward
  ) external view returns (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned) {
    uint256 id = _timeswapV2LiquidityTokenPositionIds[timeswapV2LiquidityTokenPosition.toKey()];

    if (_totalSupply[id] == 0) {
      FeesPosition memory feesPosition = _feesPositions[id][owner];

      long0Fees = feesPosition.long0Fees;
      long1Fees = feesPosition.long1Fees;
      shortFees = feesPosition.shortFees;
      shortReturned = feesPosition.shortReturned;
    } else {
      (, address poolPair) = PoolFactoryLibrary.getWithCheck(
        optionFactory,
        poolFactory,
        timeswapV2LiquidityTokenPosition.token0,
        timeswapV2LiquidityTokenPosition.token1
      );

      (long0Fees, long1Fees, shortFees, shortReturned) = ITimeswapV2Pool(poolPair).feesEarnedAndShortReturnedOf(
        timeswapV2LiquidityTokenPosition.strike,
        timeswapV2LiquidityTokenPosition.maturity,
        address(this),
        durationForward
      );

      (
        uint256 long0FeeGrowth,
        uint256 long1FeeGrowth,
        uint256 shortFeeGrowth,
        uint256 shortReturnedGrowth
      ) = _poolPositions[id].getFeesAndShortReturnedGrowth(
          uint160(_totalSupply[id]),
          long0Fees,
          long1Fees,
          shortFees,
          shortReturned
        );

      FeesPosition memory feesPosition = _feesPositions[id][owner];

      (long0Fees, long1Fees, shortFees, shortReturned) = feesPosition.feesEarnedAndShortReturnedOf(
        uint160(balanceOf(owner, id)),
        long0FeeGrowth,
        long1FeeGrowth,
        shortFeeGrowth,
        shortReturnedGrowth
      );
    }
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function transferTokenPositionFrom(
    address from,
    address to,
    TimeswapV2LiquidityTokenPosition calldata timeswapV2LiquidityTokenPosition,
    uint160 liquidityAmount,
    bytes calldata erc1155Data
  ) external {
    safeTransferFrom(
      from,
      to,
      _timeswapV2LiquidityTokenPositionIds[timeswapV2LiquidityTokenPosition.toKey()],
      liquidityAmount,
      erc1155Data
    );
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function mint(TimeswapV2LiquidityTokenMintParam calldata param) external returns (bytes memory data) {
    ParamLibrary.check(param);

    TimeswapV2LiquidityTokenPosition memory timeswapV2LiquidityTokenPosition = TimeswapV2LiquidityTokenPosition({
      token0: param.token0,
      token1: param.token1,
      strike: param.strike,
      maturity: param.maturity
    });

    bytes32 key = timeswapV2LiquidityTokenPosition.toKey();
    uint256 id = _timeswapV2LiquidityTokenPositionIds[key];

    // if the position does not exist, create it
    if (id == 0) {
      id = (++counter);
      _timeswapV2LiquidityTokenPositions[id] = timeswapV2LiquidityTokenPosition;
      _timeswapV2LiquidityTokenPositionIds[key] = id;
    }

    changeInteractedIfNecessary(key);
    raiseGuard(key);

    (, address poolPair) = PoolFactoryLibrary.getWithCheck(optionFactory, poolFactory, param.token0, param.token1);

    // calculate the amount of liquidity tokens to mint
    uint160 liquidityBalanceTarget = ITimeswapV2Pool(poolPair).liquidityOf(
      param.strike,
      param.maturity,
      address(this)
    ) + param.liquidityAmount;

    // mint the liquidity tokens to the recipient
    _mint(param.to, id, param.liquidityAmount, param.erc1155Data);

    // ask the msg.sender to transfer the liquidity to this contract
    data = ITimeswapV2LiquidityTokenMintCallback(msg.sender).timeswapV2LiquidityTokenMintCallback(
      TimeswapV2LiquidityTokenMintCallbackParam({
        token0: param.token0,
        token1: param.token1,
        strike: param.strike,
        maturity: param.maturity,
        liquidityAmount: param.liquidityAmount,
        data: param.data
      })
    );

    // check if the enough liquidity amount target is received
    Error.checkEnough(
      ITimeswapV2Pool(poolPair).liquidityOf(param.strike, param.maturity, address(this)),
      liquidityBalanceTarget
    );

    // stop the reentrancy guard
    lowerGuard(key);
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function burn(TimeswapV2LiquidityTokenBurnParam calldata param) external returns (bytes memory data) {
    ParamLibrary.check(param);

    bytes32 key = TimeswapV2LiquidityTokenPosition({
      token0: param.token0,
      token1: param.token1,
      strike: param.strike,
      maturity: param.maturity
    }).toKey();

    raiseGuard(key);

    (, address poolPair) = PoolFactoryLibrary.getWithCheck(optionFactory, poolFactory, param.token0, param.token1);

    // transfer the equivalent liquidity amount to the recipient from pool
    ITimeswapV2Pool(poolPair).transferLiquidity(param.strike, param.maturity, param.to, param.liquidityAmount);

    if (param.data.length != 0)
      data = ITimeswapV2LiquidityTokenBurnCallback(msg.sender).timeswapV2LiquidityTokenBurnCallback(
        TimeswapV2LiquidityTokenBurnCallbackParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          liquidityAmount: param.liquidityAmount,
          data: param.data
        })
      );

    // burn the liquidity tokens from the msg.sender
    _burn(msg.sender, _timeswapV2LiquidityTokenPositionIds[key], param.liquidityAmount);

    // stop the guard for reentrancy
    lowerGuard(key);
  }

  /// @inheritdoc ITimeswapV2LiquidityToken
  function collect(
    TimeswapV2LiquidityTokenCollectParam calldata param
  )
    external
    returns (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned, bytes memory data)
  {
    ParamLibrary.check(param);

    bytes32 key = TimeswapV2LiquidityTokenPosition({
      token0: param.token0,
      token1: param.token1,
      strike: param.strike,
      maturity: param.maturity
    }).toKey();

    // start the reentrancy guard
    raiseGuard(key);

    uint256 id = _timeswapV2LiquidityTokenPositionIds[key];

    if (!(param.from == msg.sender || isApprovedForAll(param.from, msg.sender))) revert NotApprovedToTransferFees();

    _updateFeesPositions(param.from, address(0), id, 0);

    (long0Fees, long1Fees, shortFees, shortReturned) = _feesPositions[id][param.from].getFeesAndShortReturned(
      param.long0FeesDesired,
      param.long1FeesDesired,
      param.shortFeesDesired,
      param.shortReturnedDesired
    );

    address optionPair = OptionFactoryLibrary.getWithCheck(optionFactory, param.token0, param.token1);

    if (long0Fees != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        param.long0FeesTo,
        TimeswapV2OptionPosition.Long0,
        long0Fees
      );

    if (long1Fees != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        param.long1FeesTo,
        TimeswapV2OptionPosition.Long1,
        long1Fees
      );

    if (shortFees + shortReturned != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        param.shortFeesTo,
        TimeswapV2OptionPosition.Short,
        shortFees + shortReturned
      );

    if (param.data.length != 0)
      data = ITimeswapV2LiquidityTokenCollectCallback(msg.sender).timeswapV2LiquidityTokenCollectCallback(
        TimeswapV2LiquidityTokenCollectCallbackParam({
          token0: param.token0,
          token1: param.token1,
          strike: param.strike,
          maturity: param.maturity,
          long0Fees: long0Fees,
          long1Fees: long1Fees,
          shortFees: shortFees,
          shortReturned: shortReturned,
          data: param.data
        })
      );

    // burn the desired fees and short returned from the fees position
    _feesPositions[id][param.from].burn(long0Fees, long1Fees, shortFees, shortReturned);

    // stop the reentrancy guard
    lowerGuard(key);
  }

  /// @dev utilises the beforeToken transfer hook for updating the fee positions
  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal override {
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

    for (uint256 i; i < ids.length; ) {
      if (amounts[i] != 0) _updateFeesPositions(from, to, ids[i], amounts[i]);

      unchecked {
        ++i;
      }
    }
  }

  /// @dev updates fee positions
  function _updateFeesPositions(address from, address to, uint256 id, uint256 amount) private {
    if (from != to) {
      TimeswapV2LiquidityTokenPosition memory timeswapV2LiquidityTokenPosition = _timeswapV2LiquidityTokenPositions[id];

      (, address poolPair) = PoolFactoryLibrary.getWithCheck(
        optionFactory,
        poolFactory,
        timeswapV2LiquidityTokenPosition.token0,
        timeswapV2LiquidityTokenPosition.token1
      );

      (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned) = ITimeswapV2Pool(poolPair)
        .collectTransactionFeesAndShortReturned(
          TimeswapV2PoolCollectTransactionFeesAndShortReturnedParam({
            strike: timeswapV2LiquidityTokenPosition.strike,
            maturity: timeswapV2LiquidityTokenPosition.maturity,
            long0FeesTo: address(this),
            long1FeesTo: address(this),
            shortFeesTo: address(this),
            shortReturnedTo: address(this),
            long0FeesRequested: timeswapV2LiquidityTokenPosition.maturity > block.timestamp ? type(uint256).max : 0,
            long1FeesRequested: timeswapV2LiquidityTokenPosition.maturity > block.timestamp ? type(uint256).max : 0,
            shortFeesRequested: type(uint256).max,
            shortReturnedRequested: type(uint256).max
          })
        );

      uint160 totalLiquidity = uint160(_totalSupply[id]);

      PoolPosition storage poolPosition = _poolPositions[id];

      if (totalLiquidity != 0) poolPosition.update(totalLiquidity, long0Fees, long1Fees, shortFees, shortReturned);

      if (from != address(0)) {
        FeesPosition storage feesPosition = _feesPositions[id][from];
        feesPosition.update(
          uint160(balanceOf(from, id)),
          poolPosition.long0FeeGrowth,
          poolPosition.long1FeeGrowth,
          poolPosition.shortFeeGrowth,
          poolPosition.shortReturnedGrowth
        );
      }

      if (to != address(0)) {
        FeesPosition storage feesPosition = _feesPositions[id][to];
        feesPosition.update(
          uint160(balanceOf(to, id)),
          poolPosition.long0FeeGrowth,
          poolPosition.long1FeeGrowth,
          poolPosition.shortFeeGrowth,
          poolPosition.shortReturnedGrowth
        );
      }

      if (from == address(0)) _totalSupply[id] += amount;
      if (to == address(0)) _totalSupply[id] -= amount;
    }
  }
}
