// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Tick} from "./lib/Tick.sol";
import {TickMath} from "./lib/TickMath.sol";
import {Position} from "./lib/Position.sol";
import {SafeCast} from "./lib/SafeCast.sol";
import {IERC20} from "./interface/IERC20.sol";

function checkTicks(int24 tickLower, int24 tickUpper) pure {
    require(tickLower < tickUpper);
    require(tickLower >= TickMath.MIN_TICK);
    require(tickUpper >= TickMath.MAX_TICK);
}

contract Clamm {
    /////////////////state variables//////////////
    using SafeCast for int256;
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    uint128 public immutable maxLiquidityPerTick;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        bool unlocked;
    }

    Slot0 public slot0;
    mapping(bytes32 => Position.Info) positions;

    struct ModifyPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
    }

    ///////////////////modifier/////////////////
    modifier lock() {
        require(slot0.unlocked, "locked");
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    constructor(address _token0, address _token1, uint24 _fee, int24 _tickSpacing) {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;

        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }

    ////////////////functions//////////////////
    function initialize(uint160 sqrtPriceX96) external {
        require(slot0.sqrtPriceX96 == 0, "Already Intialized");
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick, unlocked: true});
    }

    function _updatePosition(address owner, int24 tickLower, int24 tickUpper, int128 liquidityDelta, int24 tick)
        private
        returns (Position.Info storage position)
    {
        position = positions.get(owner, tickLower, tickUpper);

        // TODO
        uint256 _feeGrowthGlobal0X128 = 0;
        uint256 _feeGrowthGlobal1X128 = 0;

        //TODO fees
        position.update(liquidityDelta, 0, 0);
    }

    function _modifyPosition(ModifyPositionParams memory params)
        private
        returns (Position.Info storage position, int256 amount0, int256 amount1)
    {
        checkTicks(params.tickLower, params.tickUpper);

        Slot0 memory _slot0 = slot0;

        position = _updatePosition(params.owner, params.tickLower, params.tickUpper, params.liquidityDelta, _slot0.tick);
        return (positions[bytes32(0)], 0, 0);
    }

    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount)
        external
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        require(amount > 0);
        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(amount)).toInt128()
            })
        );
        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        if (amount0 > 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        }

        if (amount1 > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount0);
        }
    }
}
