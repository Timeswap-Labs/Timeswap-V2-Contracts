// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.8;

import {Ownership} from "@timeswap-labs/v2-library/contracts/Ownership.sol";

import {Error} from "@timeswap-labs/v2-library/contracts/Error.sol";

import {ITimeswapV2Option} from "@timeswap-labs/v2-option/contracts/interfaces/ITimeswapV2Option.sol";

import {TimeswapV2OptionPosition} from "@timeswap-labs/v2-option/contracts/enums/Position.sol";

import {StrikeAndMaturity} from "@timeswap-labs/v2-option/contracts/structs/StrikeAndMaturity.sol";

import {NoDelegateCall} from "./NoDelegateCall.sol";

import {ITimeswapV2Pool} from "./interfaces/ITimeswapV2Pool.sol";
import {ITimeswapV2PoolFactory} from "./interfaces/ITimeswapV2PoolFactory.sol";
import {ITimeswapV2PoolDeployer} from "./interfaces/ITimeswapV2PoolDeployer.sol";

import {ITimeswapV2PoolMintCallback} from "./interfaces/callbacks/ITimeswapV2PoolMintCallback.sol";
import {ITimeswapV2PoolBurnCallback} from "./interfaces/callbacks/ITimeswapV2PoolBurnCallback.sol";
import {ITimeswapV2PoolDeleverageCallback} from "./interfaces/callbacks/ITimeswapV2PoolDeleverageCallback.sol";
import {ITimeswapV2PoolLeverageCallback} from "./interfaces/callbacks/ITimeswapV2PoolLeverageCallback.sol";
import {ITimeswapV2PoolRebalanceCallback} from "./interfaces/callbacks/ITimeswapV2PoolRebalanceCallback.sol";

import {ReentrancyGuard} from "./libraries/ReentrancyGuard.sol";

import {LiquidityPosition, LiquidityPositionLibrary} from "./structs/LiquidityPosition.sol";

import {Pool, PoolLibrary} from "./structs/Pool.sol";
import {TimeswapV2PoolCollectProtocolFeesParam, TimeswapV2PoolCollectTransactionFeesAndShortReturnedParam, TimeswapV2PoolMintParam, TimeswapV2PoolBurnParam, TimeswapV2PoolDeleverageParam, TimeswapV2PoolLeverageParam, TimeswapV2PoolRebalanceParam, ParamLibrary} from "./structs/Param.sol";
import {TimeswapV2PoolMintChoiceCallbackParam, TimeswapV2PoolMintCallbackParam, TimeswapV2PoolBurnChoiceCallbackParam, TimeswapV2PoolBurnCallbackParam, TimeswapV2PoolDeleverageChoiceCallbackParam, TimeswapV2PoolDeleverageCallbackParam, TimeswapV2PoolLeverageCallbackParam, TimeswapV2PoolLeverageChoiceCallbackParam, TimeswapV2PoolRebalanceCallbackParam} from "./structs/CallbackParam.sol";

import {TimeswapV2PoolMint, TimeswapV2PoolBurn, TimeswapV2PoolDeleverage, TimeswapV2PoolLeverage, TimeswapV2PoolRebalance, TransactionLibrary} from "./enums/Transaction.sol";

/// @title Contract for TimeswapV2Pool
/// @author Timeswap Labs
contract TimeswapV2Pool is ITimeswapV2Pool, NoDelegateCall {
  using PoolLibrary for Pool;
  using Ownership for address;
  using LiquidityPositionLibrary for LiquidityPosition;

  /* ===== MODEL ===== */

  /// @inheritdoc ITimeswapV2Pool
  address public immutable override poolFactory;
  /// @inheritdoc ITimeswapV2Pool
  address public immutable override optionPair;
  /// @inheritdoc ITimeswapV2Pool
  uint256 public immutable override transactionFee;
  /// @inheritdoc ITimeswapV2Pool
  uint256 public immutable override protocolFee;

  mapping(uint256 => mapping(uint256 => uint96)) private reentrancyGuards;
  mapping(uint256 => mapping(uint256 => Pool)) private pools;

  StrikeAndMaturity[] private listOfPools;

  function addPoolEnumerationIfNecessary(uint256 strike, uint256 maturity) private {
    if (reentrancyGuards[strike][maturity] == ReentrancyGuard.NOT_INTERACTED) {
      reentrancyGuards[strike][maturity] = ReentrancyGuard.NOT_ENTERED;
      listOfPools.push(StrikeAndMaturity({strike: strike, maturity: maturity}));
    }
  }

  /* ===== MODIFIER ===== */
  /// @dev function to raise the reentrancy guard
  /// @param strike the strike amount
  /// @param maturity the maturity timestamp
  function raiseGuard(uint256 strike, uint256 maturity) private {
    ReentrancyGuard.check(reentrancyGuards[strike][maturity]);
    reentrancyGuards[strike][maturity] = ReentrancyGuard.ENTERED;
  }

  /// @dev function to lower the reentrancy guard
  /// @param strike the strike amount
  /// @param maturity the maturity timestamp
  function lowerGuard(uint256 strike, uint256 maturity) private {
    reentrancyGuards[strike][maturity] = ReentrancyGuard.NOT_ENTERED;
  }

  /* ===== INIT ===== */
  /// @dev constructor for the contract
  constructor() NoDelegateCall() {
    (poolFactory, optionPair, transactionFee, protocolFee) = ITimeswapV2PoolDeployer(msg.sender).parameter();
  }

  // Can be overidden for testing purposes.
  /// @dev for advancing the duration
  /// @param durationForward the durationForward seconds
  function blockTimestamp(uint96 durationForward) internal view virtual returns (uint96) {
    return uint96(block.timestamp + durationForward); // truncation is desired
  }

  function hasLiquidity(uint256 strike, uint256 maturity) private view {
    if (pools[strike][maturity].liquidity == 0) Error.requireLiquidity();
  }

  /* ===== VIEW ===== */

  /// @inheritdoc ITimeswapV2Pool
  function getByIndex(uint256 id) external view override returns (StrikeAndMaturity memory) {
    return listOfPools[id];
  }

  /// @inheritdoc ITimeswapV2Pool
  function numberOfPools() external view override returns (uint256) {
    return listOfPools.length;
  }

  /// @inheritdoc ITimeswapV2Pool
  function totalLiquidity(uint256 strike, uint256 maturity) external view override returns (uint160) {
    return pools[strike][maturity].liquidity;
  }

  /// @inheritdoc ITimeswapV2Pool
  function sqrtInterestRate(uint256 strike, uint256 maturity) external view override returns (uint160) {
    return pools[strike][maturity].sqrtInterestRate;
  }

  /// @inheritdoc ITimeswapV2Pool
  function liquidityOf(uint256 strike, uint256 maturity, address owner) external view override returns (uint160) {
    return pools[strike][maturity].liquidityPositions[owner].liquidity;
  }

  /// @inheritdoc ITimeswapV2Pool
  function feesEarnedAndShortReturnedGrowth(
    uint256 strike,
    uint256 maturity
  )
    external
    view
    returns (uint256 long0FeeGrowth, uint256 long1FeeGrowth, uint256 shortFeeGrowth, uint256 shortReturnedGrowth)
  {
    return pools[strike][maturity].feesEarnedAndShortReturnedGrowth(maturity, blockTimestamp(0));
  }

  /// @inheritdoc ITimeswapV2Pool
  function feesEarnedAndShortReturnedGrowth(
    uint256 strike,
    uint256 maturity,
    uint96 durationForward
  )
    external
    view
    returns (uint256 long0FeeGrowth, uint256 long1FeeGrowth, uint256 shortFeeGrowth, uint256 shortReturnedGrowth)
  {
    return pools[strike][maturity].feesEarnedAndShortReturnedGrowth(maturity, blockTimestamp(durationForward));
  }

  /// @inheritdoc ITimeswapV2Pool
  function feesEarnedAndShortReturnedOf(
    uint256 strike,
    uint256 maturity,
    address owner
  ) external view override returns (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned) {
    return pools[strike][maturity].feesEarnedAndShortReturnedOf(maturity, owner, blockTimestamp(0));
  }

  /// @inheritdoc ITimeswapV2Pool
  function feesEarnedAndShortReturnedOf(
    uint256 strike,
    uint256 maturity,
    address owner,
    uint96 durationForward
  ) external view override returns (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned) {
    return pools[strike][maturity].feesEarnedAndShortReturnedOf(maturity, owner, blockTimestamp(durationForward));
  }

  /// @inheritdoc ITimeswapV2Pool
  function protocolFeesEarned(
    uint256 strike,
    uint256 maturity
  ) external view override returns (uint256 long0ProtocolFees, uint256 long1ProtocolFees, uint256 shortProtocolFees) {
    return pools[strike][maturity].protocolFeesEarned();
  }

  /// @inheritdoc ITimeswapV2Pool
  function totalLongBalance(
    uint256 strike,
    uint256 maturity
  ) external view override returns (uint256 long0Amount, uint256 long1Amount) {
    Pool storage pool = pools[strike][maturity];
    long0Amount = pool.long0Balance;
    long1Amount = pool.long1Balance;
  }

  /// @inheritdoc ITimeswapV2Pool
  function totalLongBalanceAdjustFees(
    uint256 strike,
    uint256 maturity
  ) external view override returns (uint256 long0Amount, uint256 long1Amount) {
    (long0Amount, long1Amount) = pools[strike][maturity].totalLongBalanceAdjustFees(transactionFee);
  }

  /// @inheritdoc ITimeswapV2Pool
  function totalPositions(
    uint256 strike,
    uint256 maturity
  ) external view override returns (uint256 longAmount, uint256 shortAmount) {
    (longAmount, shortAmount) = pools[strike][maturity].totalPositions(maturity, blockTimestamp(0));
  }

  /* ===== UPDATE ===== */

  /// @inheritdoc ITimeswapV2Pool
  function transferLiquidity(uint256 strike, uint256 maturity, address to, uint160 liquidityAmount) external override {
    hasLiquidity(strike, maturity);

    if (blockTimestamp(0) > maturity) Error.alreadyMatured(maturity, blockTimestamp(0));
    if (to == address(0)) Error.zeroAddress();
    if (liquidityAmount == 0) Error.zeroInput();

    pools[strike][maturity].transferLiquidity(maturity, to, liquidityAmount, blockTimestamp(0));

    emit TransferLiquidity(strike, maturity, msg.sender, to, liquidityAmount);
  }

  /// @inheritdoc ITimeswapV2Pool
  function initialize(uint256 strike, uint256 maturity, uint160 rate) external override noDelegateCall {
    if (strike == 0) Error.cannotBeZero();
    if (maturity < blockTimestamp(0)) Error.alreadyMatured(maturity, blockTimestamp(0));
    if (rate == 0) Error.cannotBeZero();
    addPoolEnumerationIfNecessary(strike, maturity);

    pools[strike][maturity].initialize(rate);
  }

  /// @inheritdoc ITimeswapV2Pool
  function collectProtocolFees(
    TimeswapV2PoolCollectProtocolFeesParam calldata param
  ) external override noDelegateCall returns (uint256 long0Amount, uint256 long1Amount, uint256 shortAmount) {
    ParamLibrary.check(param);
    raiseGuard(param.strike, param.maturity);

    // Can only be called by the TimeswapV2Pool factory owner.
    ITimeswapV2PoolFactory(poolFactory).owner().checkIfOwner();

    // Calculate the main logic of protocol fee.
    (long0Amount, long1Amount, shortAmount) = pools[param.strike][param.maturity].collectProtocolFees(
      param.long0Requested,
      param.long1Requested,
      param.shortRequested
    );

    collect(
      param.strike,
      param.maturity,
      param.long0To,
      param.long1To,
      param.shortTo,
      long0Amount,
      long1Amount,
      shortAmount
    );

    lowerGuard(param.strike, param.maturity);

    emit CollectProtocolFees(
      param.strike,
      param.maturity,
      msg.sender,
      param.long0To,
      param.long1To,
      param.shortTo,
      long0Amount,
      long1Amount,
      shortAmount
    );
  }

  /// @inheritdoc ITimeswapV2Pool
  function collectTransactionFeesAndShortReturned(
    TimeswapV2PoolCollectTransactionFeesAndShortReturnedParam calldata param
  )
    external
    override
    noDelegateCall
    returns (uint256 long0Fees, uint256 long1Fees, uint256 shortFees, uint256 shortReturned)
  {
    ParamLibrary.check(param);
    raiseGuard(param.strike, param.maturity);

    // Calculate the main logic of transaction fee.
    (long0Fees, long1Fees, shortFees, shortReturned) = pools[param.strike][param.maturity]
      .collectTransactionFeesAndShortReturned(
        param.maturity,
        param.long0FeesRequested,
        param.long1FeesRequested,
        param.shortFeesRequested,
        param.shortReturnedRequested,
        blockTimestamp(0)
      );

    collect(
      param.strike,
      param.maturity,
      param.long0FeesTo,
      param.long1FeesTo,
      param.shortFeesTo,
      long0Fees,
      long1Fees,
      shortFees
    );

    if (shortReturned != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        param.shortReturnedTo,
        TimeswapV2OptionPosition.Short,
        shortReturned
      );

    lowerGuard(param.strike, param.maturity);

    emit CollectTransactionFeesAndShortReturned(
      param.strike,
      param.maturity,
      msg.sender,
      param.long0FeesTo,
      param.long1FeesTo,
      param.shortFeesTo,
      param.shortReturnedTo,
      long0Fees,
      long1Fees,
      shortFees,
      shortReturned
    );
  }

  /// @dev Transfer long0 positions, long1 positions, and/or short positions to the recipients.
  /// @param strike The strike price of the pool.
  /// @param maturity The maturity of the pool.
  /// @param long0To The recipient of long0 positions.
  /// @param long1To The recipient of long1 positions.
  /// @param shortTo The recipient of short positions.
  /// @param long0Amount The amount of long0 positions wanted.
  /// @param long1Amount The amount of long1 positions wanted.
  /// @param shortAmount The amount of short positions wanted.
  function collect(
    uint256 strike,
    uint256 maturity,
    address long0To,
    address long1To,
    address shortTo,
    uint256 long0Amount,
    uint256 long1Amount,
    uint256 shortAmount
  ) private {
    if (long0Amount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        strike,
        maturity,
        long0To,
        TimeswapV2OptionPosition.Long0,
        long0Amount
      );

    if (long1Amount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        strike,
        maturity,
        long1To,
        TimeswapV2OptionPosition.Long1,
        long1Amount
      );

    if (shortAmount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        strike,
        maturity,
        shortTo,
        TimeswapV2OptionPosition.Short,
        shortAmount
      );
  }

  /// @inheritdoc ITimeswapV2Pool
  function mint(
    TimeswapV2PoolMintParam calldata param
  )
    external
    override
    returns (uint160 liquidityAmount, uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data)
  {
    return mint(param, false, 0);
  }

  /// @inheritdoc ITimeswapV2Pool
  function mint(
    TimeswapV2PoolMintParam calldata param,
    uint96 durationForward
  )
    external
    override
    returns (uint160 liquidityAmount, uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data)
  {
    return mint(param, true, durationForward);
  }

  /// @dev deposit Short and Long tokens and mints Liquidity
  /// @dev can be only called before the maturity.
  /// @notice Will always revert with error Quote after the final callback.
  /// @param param it is a struct that contains the parameters of the mint function.
  /// @param durationForward The duration of time moved forward.
  /// @param isQuote Whether used for quoting purposes
  /// @return liquidityAmount The amount of liquidity minted.
  /// @return long0Amount The amount of long0 deposited.
  /// @return long1Amount The amount of long1 deposited.
  /// @return shortAmount The amount of short deposited.
  /// @return data the data used for the callbacks.
  function mint(
    TimeswapV2PoolMintParam calldata param,
    bool isQuote,
    uint96 durationForward
  )
    private
    noDelegateCall
    returns (uint160 liquidityAmount, uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data)
  {
    ParamLibrary.check(param, blockTimestamp(durationForward));
    raiseGuard(param.strike, param.maturity);

    // Calculate the main logic of mint function.
    (liquidityAmount, long0Amount, long1Amount, shortAmount, data) = pools[param.strike][param.maturity].mint(
      param,
      blockTimestamp(durationForward)
    );

    // Calculate the amount of long0 position, long1 position, and short position required by the pool.

    // long0Amount chosen could be zero. Skip the calculation for gas efficiency.
    uint256 long0BalanceTarget;
    if (long0Amount != 0)
      long0BalanceTarget =
        ITimeswapV2Option(optionPair).positionOf(
          param.strike,
          param.maturity,
          address(this),
          TimeswapV2OptionPosition.Long0
        ) +
        long0Amount;

    // long1Amount chosen could be zero. Skip the calculation for gas efficiency.
    uint256 long1BalanceTarget;
    if (long1Amount != 0)
      long1BalanceTarget =
        ITimeswapV2Option(optionPair).positionOf(
          param.strike,
          param.maturity,
          address(this),
          TimeswapV2OptionPosition.Long1
        ) +
        long1Amount;

    // shortAmount cannot be zero.
    uint256 shortBalanceTarget = ITimeswapV2Option(optionPair).positionOf(
      param.strike,
      param.maturity,
      address(this),
      TimeswapV2OptionPosition.Short
    ) + shortAmount;

    // Ask the msg.sender to transfer the positions into this address.
    data = ITimeswapV2PoolMintCallback(msg.sender).timeswapV2PoolMintCallback(
      TimeswapV2PoolMintCallbackParam({
        strike: param.strike,
        maturity: param.maturity,
        long0Amount: long0Amount,
        long1Amount: long1Amount,
        shortAmount: shortAmount,
        liquidityAmount: liquidityAmount,
        data: data
      })
    );

    if (isQuote) revert Quote();

    // Check when the position balance targets are reached.

    if (long0Amount != 0)
      Error.checkEnough(
        ITimeswapV2Option(optionPair).positionOf(
          param.strike,
          param.maturity,
          address(this),
          TimeswapV2OptionPosition.Long0
        ),
        long0BalanceTarget
      );

    if (long1Amount != 0)
      Error.checkEnough(
        ITimeswapV2Option(optionPair).positionOf(
          param.strike,
          param.maturity,
          address(this),
          TimeswapV2OptionPosition.Long1
        ),
        long1BalanceTarget
      );

    Error.checkEnough(
      ITimeswapV2Option(optionPair).positionOf(
        param.strike,
        param.maturity,
        address(this),
        TimeswapV2OptionPosition.Short
      ),
      shortBalanceTarget
    );

    lowerGuard(param.strike, param.maturity);

    emit Mint(
      param.strike,
      param.maturity,
      msg.sender,
      param.to,
      liquidityAmount,
      long0Amount,
      long1Amount,
      shortAmount
    );
  }

  /// @inheritdoc ITimeswapV2Pool
  function burn(
    TimeswapV2PoolBurnParam calldata param
  )
    external
    override
    returns (uint160 liquidityAmount, uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data)
  {
    return burn(param, false, 0);
  }

  /// @inheritdoc ITimeswapV2Pool
  function burn(
    TimeswapV2PoolBurnParam calldata param,
    uint96 durationForward
  )
    external
    override
    returns (uint160 liquidityAmount, uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data)
  {
    return burn(param, true, durationForward);
  }

  /// @dev burn Liquidity and receive Short and Long tokens
  /// @dev can be only called before the maturity.
  /// @dev after the maturity of the pool, the long0 and long1 tokens are zero. And the short tokens are added into the transaction fees.
  /// @dev if the user wants to burn the liquidity after the maturity, they should call the collectTransactionFee function.
  /// @param param it is a struct that contains the parameters of the burn function
  /// @param durationForward The duration of time moved forward.
  /// @param isQuote Whether is used for quoting purposes.
  /// @return liquidityAmount The amount of liquidity burned.
  /// @return long0Amount The amount of long0 withdrawn.
  /// @return long1Amount The amount of long1 withdrawn.
  /// @return shortAmount The amount of short withdrawn.
  /// @return data the data used for the callbacks.
  function burn(
    TimeswapV2PoolBurnParam calldata param,
    bool isQuote,
    uint96 durationForward
  )
    private
    noDelegateCall
    returns (uint160 liquidityAmount, uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data)
  {
    hasLiquidity(param.strike, param.maturity);

    ParamLibrary.check(param, blockTimestamp(durationForward));
    raiseGuard(param.strike, param.maturity);

    Pool storage pool = pools[param.strike][param.maturity];

    // Calculate the main logic of burn function.
    (liquidityAmount, long0Amount, long1Amount, shortAmount, data) = pool.burn(param, blockTimestamp(durationForward));

    // Transfer the positions to the recipients.

    // Long0 amount can be zero.
    if (long0Amount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        param.long0To,
        TimeswapV2OptionPosition.Long0,
        long0Amount
      );

    // Long1 amount can be zero.
    if (long1Amount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        param.long1To,
        TimeswapV2OptionPosition.Long1,
        long1Amount
      );

    // Short amount cannot be zero.
    ITimeswapV2Option(optionPair).transferPosition(
      param.strike,
      param.maturity,
      param.shortTo,
      TimeswapV2OptionPosition.Short,
      shortAmount
    );

    data = ITimeswapV2PoolBurnCallback(msg.sender).timeswapV2PoolBurnCallback(
      TimeswapV2PoolBurnCallbackParam({
        strike: param.strike,
        maturity: param.maturity,
        long0Amount: long0Amount,
        long1Amount: long1Amount,
        shortAmount: shortAmount,
        liquidityAmount: liquidityAmount,
        data: data
      })
    );

    if (isQuote) revert Quote();

    pool.liquidityPositions[msg.sender].burn(liquidityAmount);

    lowerGuard(param.strike, param.maturity);

    emit Burn(
      param.strike,
      param.maturity,
      msg.sender,
      param.long0To,
      param.long1To,
      param.shortTo,
      liquidityAmount,
      long0Amount,
      long1Amount,
      shortAmount
    );
  }

  /// @inheritdoc ITimeswapV2Pool
  function deleverage(
    TimeswapV2PoolDeleverageParam calldata param
  ) external override returns (uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data) {
    return deleverage(param, false, 0);
  }

  /// @inheritdoc ITimeswapV2Pool
  function deleverage(
    TimeswapV2PoolDeleverageParam calldata param,
    uint96 durationForward
  ) external override returns (uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data) {
    return deleverage(param, true, durationForward);
  }

  /// @dev deposit Long tokens and receive Short tokens
  /// @dev can be only called before the maturity.
  /// @notice Will always revert with error Quote after the final callback.
  /// @param param it is a struct that contains the parameters of the deleverage function.
  /// @param durationForward The duration of time moved forward.
  /// @param isQuote Whether is used for quoting purposes.
  /// @return long0Amount The amount of long0 deposited.
  /// @return long1Amount The amount of long1 deposited.
  /// @return shortAmount The amount of short received.
  /// @return data the data used for the callbacks.
  function deleverage(
    TimeswapV2PoolDeleverageParam calldata param,
    bool isQuote,
    uint96 durationForward
  ) private noDelegateCall returns (uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data) {
    hasLiquidity(param.strike, param.maturity);
    ParamLibrary.check(param, blockTimestamp(durationForward));
    raiseGuard(param.strike, param.maturity);

    // Calculate the main logic of deleverage function.
    (long0Amount, long1Amount, shortAmount, data) = pools[param.strike][param.maturity].deleverage(
      param,
      transactionFee,
      protocolFee,
      blockTimestamp(durationForward)
    );

    // Calculate the amount of long0 position and long1 position required by the pool.

    // long0Amount chosen could be zero. Skip the calculation for gas efficiency.
    uint256 long0BalanceTarget;
    if (long0Amount != 0)
      long0BalanceTarget =
        ITimeswapV2Option(optionPair).positionOf(
          param.strike,
          param.maturity,
          address(this),
          TimeswapV2OptionPosition.Long0
        ) +
        long0Amount;

    // long1Amount chosen could be zero. Skip the calculation for gas efficiency.
    uint256 long1BalanceTarget;
    if (long1Amount != 0)
      long1BalanceTarget =
        ITimeswapV2Option(optionPair).positionOf(
          param.strike,
          param.maturity,
          address(this),
          TimeswapV2OptionPosition.Long1
        ) +
        long1Amount;

    // Transfer short positions to the recipient.
    ITimeswapV2Option(optionPair).transferPosition(
      param.strike,
      param.maturity,
      param.to,
      TimeswapV2OptionPosition.Short,
      shortAmount
    );

    // Ask the msg.sender to transfer the positions into this address.
    data = ITimeswapV2PoolDeleverageCallback(msg.sender).timeswapV2PoolDeleverageCallback(
      TimeswapV2PoolDeleverageCallbackParam({
        strike: param.strike,
        maturity: param.maturity,
        long0Amount: long0Amount,
        long1Amount: long1Amount,
        shortAmount: shortAmount,
        data: data
      })
    );

    if (isQuote) revert Quote();

    // Check when the position balance targets are reached.

    if (long0Amount != 0)
      Error.checkEnough(
        ITimeswapV2Option(optionPair).positionOf(
          param.strike,
          param.maturity,
          address(this),
          TimeswapV2OptionPosition.Long0
        ),
        long0BalanceTarget
      );

    if (long1Amount != 0)
      Error.checkEnough(
        ITimeswapV2Option(optionPair).positionOf(
          param.strike,
          param.maturity,
          address(this),
          TimeswapV2OptionPosition.Long1
        ),
        long1BalanceTarget
      );

    lowerGuard(param.strike, param.maturity);

    emit Deleverage(param.strike, param.maturity, msg.sender, param.to, long0Amount, long1Amount, shortAmount);
  }

  /// @inheritdoc ITimeswapV2Pool
  function leverage(
    TimeswapV2PoolLeverageParam calldata param
  ) external override returns (uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data) {
    return leverage(param, false, 0);
  }

  /// @inheritdoc ITimeswapV2Pool
  function leverage(
    TimeswapV2PoolLeverageParam calldata param,
    uint96 durationForward
  ) external override returns (uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data) {
    return leverage(param, true, durationForward);
  }

  /// @dev deposit Short tokens and receive Long tokens
  /// @dev can be only called before the maturity.
  /// @notice Will always revert with error Quote after the final callback.
  /// @param param it is a struct that contains the parameters of the leverage function.
  /// @param durationForward The duration of time moved forward.
  /// @param isQuote Whether is used for quoting purposes.
  /// @return long0Amount The amount of long0 received.
  /// @return long1Amount The amount of long1 received.
  /// @return shortAmount The amount of short deposited.
  /// @return data the data used for the callbacks.
  function leverage(
    TimeswapV2PoolLeverageParam calldata param,
    bool isQuote,
    uint96 durationForward
  ) private noDelegateCall returns (uint256 long0Amount, uint256 long1Amount, uint256 shortAmount, bytes memory data) {
    hasLiquidity(param.strike, param.maturity);
    ParamLibrary.check(param, blockTimestamp(durationForward));
    raiseGuard(param.strike, param.maturity);

    // Calculate the main logic of leverage function.
    (long0Amount, long1Amount, shortAmount, data) = pools[param.strike][param.maturity].leverage(
      param,
      transactionFee,
      protocolFee,
      blockTimestamp(durationForward)
    );

    // Calculate the amount of short position required by the pool.

    uint256 balanceTarget = ITimeswapV2Option(optionPair).positionOf(
      param.strike,
      param.maturity,
      address(this),
      TimeswapV2OptionPosition.Short
    ) + shortAmount;

    // Transfer the positions to the recipients.

    if (long0Amount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        param.long0To,
        TimeswapV2OptionPosition.Long0,
        long0Amount
      );

    if (long1Amount != 0)
      ITimeswapV2Option(optionPair).transferPosition(
        param.strike,
        param.maturity,
        param.long1To,
        TimeswapV2OptionPosition.Long1,
        long1Amount
      );

    // Ask the msg.sender to transfer the positions into this address.
    data = ITimeswapV2PoolLeverageCallback(msg.sender).timeswapV2PoolLeverageCallback(
      TimeswapV2PoolLeverageCallbackParam({
        strike: param.strike,
        maturity: param.maturity,
        long0Amount: long0Amount,
        long1Amount: long1Amount,
        shortAmount: shortAmount,
        data: data
      })
    );

    if (isQuote) revert Quote();

    // Check when the position balance targets are reached.

    Error.checkEnough(
      ITimeswapV2Option(optionPair).positionOf(
        param.strike,
        param.maturity,
        address(this),
        TimeswapV2OptionPosition.Short
      ),
      balanceTarget
    );

    lowerGuard(param.strike, param.maturity);

    emit Leverage(
      param.strike,
      param.maturity,
      msg.sender,
      param.long0To,
      param.long1To,
      long0Amount,
      long1Amount,
      shortAmount
    );
  }

  /// @inheritdoc ITimeswapV2Pool
  function rebalance(
    TimeswapV2PoolRebalanceParam calldata param
  ) external override noDelegateCall returns (uint256 long0Amount, uint256 long1Amount, bytes memory data) {
    hasLiquidity(param.strike, param.maturity);
    ParamLibrary.check(param, blockTimestamp(0));
    raiseGuard(param.strike, param.maturity);

    // Calculate the main logic of rebalance function.
    (long0Amount, long1Amount) = pools[param.strike][param.maturity].rebalance(param, transactionFee, protocolFee);

    // Calculate the amount of long position required by the pool.

    uint256 balanceTarget = ITimeswapV2Option(optionPair).positionOf(
      param.strike,
      param.maturity,
      address(this),
      param.isLong0ToLong1 ? TimeswapV2OptionPosition.Long0 : TimeswapV2OptionPosition.Long1
    ) + (param.isLong0ToLong1 ? long0Amount : long1Amount);

    // Transfer the positions to the recipients.

    ITimeswapV2Option(optionPair).transferPosition(
      param.strike,
      param.maturity,
      param.to,
      param.isLong0ToLong1 ? TimeswapV2OptionPosition.Long1 : TimeswapV2OptionPosition.Long0,
      param.isLong0ToLong1 ? long1Amount : long0Amount
    );

    // Ask the msg.sender to transfer the positions into this address.
    data = ITimeswapV2PoolRebalanceCallback(msg.sender).timeswapV2PoolRebalanceCallback(
      TimeswapV2PoolRebalanceCallbackParam({
        strike: param.strike,
        maturity: param.maturity,
        isLong0ToLong1: param.isLong0ToLong1,
        long0Amount: long0Amount,
        long1Amount: long1Amount,
        data: param.data
      })
    );

    // Check when the position balance targets are reached.

    Error.checkEnough(
      ITimeswapV2Option(optionPair).positionOf(
        param.strike,
        param.maturity,
        address(this),
        param.isLong0ToLong1 ? TimeswapV2OptionPosition.Long0 : TimeswapV2OptionPosition.Long1
      ),
      balanceTarget
    );

    lowerGuard(param.strike, param.maturity);

    emit Rebalance(param.strike, param.maturity, msg.sender, param.to, param.isLong0ToLong1, long0Amount, long1Amount);
  }
}
