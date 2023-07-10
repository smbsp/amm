// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/AutomatedMarketMaker.sol";
import "../src/Token.sol";
import "../src/ERC777Token.sol";

contract AutomatedMarketMakerTest is Test {
    AutomatedMarketMaker public amm;

    Token public token_0;
    Token public token_1;
    ERC777Token public token_2;

    function setUp() public {
        string memory name_0 = "Token 0";
        string memory symbol_0 = "TKN_0";
        string memory name_1 = "Token 1";
        string memory symbol_1 = "TKN_1";

        token_0 = new Token(name_0, symbol_0);
        token_1 = new Token(name_1, symbol_1);

        amm = new AutomatedMarketMaker();
    }

    // @dev create pool
    function testCreatePool() public {
        amm.createPool(address(token_0), address(token_1));
        assertEq(amm.numberOfPools(), 1);
    }

    function testERC20() public {
        bool isErc20 = amm.isERC20(address(token_0));
        assertEq(isErc20, true);
    }

    // function testERC20Revert() public {
    //     string memory name_2 = "Token 2";
    //     string memory symbol_2 = "TKN_2";
    //     address[] memory defaultOperators = new address[](1);
    //     token_2 = new ERC777Token(name_2, symbol_2, defaultOperators);
    //     bool isErc20 = amm.isERC20(address(token_2));
    //     assertEq(isErc20, false);
    // }

    // @dev deposit 1:1 and check exchange rate == 1
    function testDeposit_1_to_1() public {
        uint256 PID = amm.createPool(address(token_0), address(token_1));

        uint256 token_0_amount = 100_000e18;
        uint256 token_1_amount = 100_000e18;

        token_0.approve(address(amm), token_0_amount);
        token_1.approve(address(amm), token_1_amount);

        amm.deposit(0, token_0_amount, token_1_amount);
        (uint256 rate,) = amm.totalValueLocked(PID, address(token_0));
        assertEq(rate, 1e18);
    }

    // @dev deposit 1:1 and swap 100 token_0 for token_1
    function testSwap_1() public {
        uint256 PID = amm.createPool(address(token_0), address(token_1));

        // 1:1
        uint256 token_0_amount = 100_000e18;
        uint256 token_1_amount = 100_000e18;

        token_0.approve(address(amm), token_0_amount);
        token_1.approve(address(amm), token_1_amount);
        amm.deposit(0, token_0_amount, token_1_amount);
        (uint256 rate,) = amm.totalValueLocked(PID, address(token_0));
        assertEq(rate, 1e18);

        console.log("Exchange Rate t_0: ");
        console.logUint(uint256(rate));

        // swapping 100 token_0 for token_1
        uint256 token_0_amount_to_swap = 100e18;
        token_0.approve(address(amm), token_0_amount_to_swap);
        uint256 token_1_out = amm.swap(PID, address(token_0), token_0_amount_to_swap);

        // 100 token_0 should be worth ~99.8 token_1
        assert(998e17 < token_1_out);

        console.log("Exchange Rate t_1: ");
        console.logUint(uint256(rate));

        console.log("Tokens 1 received: ");
        console.logUint(token_1_out);
    }

    // @dev deposit 2:1 and swap 100 token_0 for token_1
    function testSwap_2() public {
        uint256 PID = amm.createPool(address(token_0), address(token_1));

        // 2:1
        uint256 token_0_amount = 100_000e18;
        uint256 token_1_amount = 50_000e18;

        token_0.approve(address(amm), token_0_amount);
        token_1.approve(address(amm), token_1_amount);
        amm.deposit(0, token_0_amount, token_1_amount);
        (uint256 rate,) = amm.totalValueLocked(PID, address(token_0));
        assertEq(rate, 2e18);

        // swapping 100 token_0 for token_1
        uint256 token_0_amount_to_swap = 100e18;
        token_0.approve(address(amm), token_0_amount_to_swap);
        uint256 token_1_out = amm.swap(PID, address(token_0), token_0_amount_to_swap);

        // 100 token_0 should be worth ~49.9 token_1
        assert(499e17 < token_1_out);

        console.logUint(token_1_out);
        console.logUint(uint256(rate));
    }

    // @dev deposit 1:1 and swap 5% of tvl of token_0 for token_1
    function testSwap_3() public {
        uint256 PID = amm.createPool(address(token_0), address(token_1));

        // 1:1
        uint256 token_0_amount = 100_000e18;
        uint256 token_1_amount = 100_000e18;

        token_0.approve(address(amm), token_0_amount);
        token_1.approve(address(amm), token_1_amount);
        amm.deposit(0, token_0_amount, token_1_amount);
        (uint256 rate,) = amm.totalValueLocked(PID, address(token_0));
        assertEq(rate, 1e18);

        // swapping 100 token_0 for token_1
        uint256 token_0_amount_to_swap = 10_000e18;
        token_0.approve(address(amm), token_0_amount_to_swap);
        uint256 token_1_out = amm.swap(PID, address(token_0), token_0_amount_to_swap);

        // 10_000 token_0 should be worth ~8_333 token_1
        // 16% slippage given the tvl of pool is 200k and swap is 5% of tvl
        assert(8333e18 < token_1_out);

        console.logUint(token_1_out);
        console.logUint(uint256(rate));
    }

    // @dev deposit 1:1 and swap token_0 for token_1 and then token_0 for token_1 and check exchange rate
    function testSwap_4() public {
        uint256 PID = amm.createPool(address(token_0), address(token_1));

        // 1:1
        uint256 token_0_amount = 1_000_000e18;
        uint256 token_1_amount = 1_000_000e18;

        token_0.approve(address(amm), token_0_amount);
        token_1.approve(address(amm), token_1_amount);
        amm.deposit(0, token_0_amount, token_1_amount);
        (uint256 rate,) = amm.totalValueLocked(PID, address(token_0));
        assertEq(rate, 1e18);

        // swapping 1000 token_0 for token_1
        uint256 token_0_amount_to_swap = 1_000e18;
        token_0.approve(address(amm), token_0_amount_to_swap);
        amm.swap(PID, address(token_0), token_0_amount_to_swap);
        (uint256 rate_0,) = amm.totalValueLocked(PID, address(token_0));

        // swapping 1000 token_1 for token_0
        uint256 token_1_amount_to_swap = 1_000e18;
        token_1.approve(address(amm), token_1_amount_to_swap);
        amm.swap(PID, address(token_1), token_1_amount_to_swap);

        (uint256 rate_1,) = amm.totalValueLocked(PID, address(token_1));
        assertEq((rate_0 - rate_1) / 1e14, 19);

        // within 0.2%
        console.log("rate_0 - rate_1:");
        console.log(rate_0 - rate_1);
    }
}
