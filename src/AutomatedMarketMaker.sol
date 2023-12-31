// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SharedReentrancyGuard} from "./globalreenterancyprotection/SharedReentrancyGuard.sol";

contract AutomatedMarketMaker is SharedReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant PRECISION = 1e18;

    // @dev struct for pool
    struct Pool {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

    // @dev struct for user liquidity position
    struct Position {
        uint256 amount0;
        uint256 amount1;
    }

    // @dev pool id => Pool struct
    mapping(uint256 => Pool) public Pools;

    // @dev array of pool ids
    uint256[] public PIDs;

    // @dev user address => Position struct
    mapping(address => Position) public Positions;

    // @dev create pool
    function createPool(address token0, address token1) public returns (uint256) {
        uint256 PID = PIDs.length;

        require(token0 != address(0), "not initialized X");
        require(token1 != address(0), "not initialized Y");

        require(isERC20(token0), "Token0 must be ERC20");
        require(isERC20(token1), "Token1 must be ERC20");

        Pools[PID].token0 = token0;
        Pools[PID].token1 = token1;

        PIDs.push(PID);

        return PID;
    }

    // @dev deposit tokens into pool and create liquidity position
    function deposit(uint256 PID, uint256 amount_token0, uint256 amount_token1) public {
        address token0 = Pools[PID].token0;
        address token1 = Pools[PID].token1;

        require(token0 != address(0), "not initialized X");
        require(token1 != address(0), "not initialized Y");

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount_token0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount_token1);

        Pools[PID].amount0 += amount_token0;
        Pools[PID].amount1 += amount_token1;

        Positions[msg.sender].amount0 = amount_token0;
        Positions[msg.sender].amount1 = amount_token1;
    }

    // @dev withdraw tokens from pool and destroy liquidity position
    function withdraw() public {
        // TODO
        // @dev withdraw tokens from pool without affecting the exchange rate
        /*
    uint token_0_amount = Positions[msg.sender].amount0;
    uint token_1_amount = Positions[msg.sender].amount1;
        */
    }

    // @dev hypothetical swap:
    // x = 5
    // y = 10
    // k = x*y
    // dx = 1
    // k = (x+1) * (y+dy)
    // 50 = (5+1) * (10+dy)
    // 50 = 6 * (10 + dy)
    // 50 = 60+6dy
    // -10 = 6dy
    // -10/6 = dy
    // -1.666
    // amountOut = (-dx * y) / (dx + x)

    // @dev swap tokens in pool
    function swap(uint256 PID, address tokenIn, uint256 amount) public returns (uint256) {
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amount));

        address tokenOut = getOtherTokenAddr(PID, tokenIn);
        uint256 amountOut;

        if (Pools[PID].token0 == tokenIn) {
            // amount out Y
            // Pools[PID].amount0 += amount;
            amountOut = (amount * (Pools[PID].amount1)) / (amount + Pools[PID].amount0);
            Pools[PID].amount0 += amount;
            Pools[PID].amount1 -= amountOut;
        } else {
            // amount out X
            // Pools[PID].amount1 += amount;
            amountOut = (amount * (Pools[PID].amount0)) / (amount + Pools[PID].amount1);
            Pools[PID].amount1 += amount;
            Pools[PID].amount0 -= amountOut;
        }
        // transfer amount token out
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        return amountOut;
    }

    // VIEW FUNCTIONS

    // X * Y = K

    // pool = 10x & 5y
    // 2x = 1y

    // exchange rate = (10x / 5y)
    // exchange_rate = 2
    // 2 * amount y + amount x = 20
    // TVL = 20x

    // @dev given pool id and token address, return the exchange rate and total value locked
    function totalValueLocked(uint256 PID, address token0) public view returns (uint256 rate, uint256 tvl) {
        address poolX = Pools[PID].token0;

        if (token0 == poolX) {
            uint256 amountX = Pools[PID].amount0;
            uint256 amountY = Pools[PID].amount1;

            rate = (amountX * PRECISION) / amountY;
            tvl = (rate * amountY) + amountX;
        } else {
            uint256 amountX = Pools[PID].amount1;
            uint256 amountY = Pools[PID].amount0;

            rate = (amountX * PRECISION) / amountY;
            tvl = (rate * amountY) + amountX;
        }

        return (rate, tvl);
    }

    // @dev given a pool id and a token address, return the other token address
    function getOtherTokenAddr(uint256 PID, address token0) public view returns (address token1) {
        address poolX = Pools[PID].token0;
        address poolY = Pools[PID].token1;

        if (token0 == poolX) {
            token1 = poolY;
        }
        if (token0 == poolY) {
            token1 = poolX;
        }
        return token1;
    }

    // @dev get number of pools in contract
    function numberOfPools() public view returns (uint256) {
        return PIDs.length;
    }

    function isERC20(address token) public view returns (bool) {
        uint256 success;
        uint256 result;
        // check if token supports the ERC20 interface by querying the 'totalSupply' function
        // if the call fails or returns a value other than 0, it is considered an ERC20 token
        bytes memory encodedParams = abi.encodeWithSignature("totalSupply()");
        assembly {
            let encodedParams_ptr := add(encodedParams, 0x20)
            let encodedParams_size := mload(encodedParams)
            let output := mload(0x40) // use free memory for output storage
            success := staticcall(gas(), token, encodedParams_ptr, encodedParams_size, output, 0x20)
            result := mload(output)
        }
        return (success != 0 && result != 0);
    }
}
