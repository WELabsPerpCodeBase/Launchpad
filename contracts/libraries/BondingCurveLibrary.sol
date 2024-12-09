// SPDX-License-Identifier: MIT 
pragma solidity >= 0.8.0;

library BondingCurveLibrary {
        // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn != 0, 'INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn != 0 && reserveOut != 0, 'INSUFFICIENT_LIQUIDITY');
        uint numerator = amountIn * reserveOut;
        uint denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut != 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn != 0 && reserveOut != 0, 'INSUFFICIENT_LIQUIDITY');
        uint numerator = amountOut * reserveIn;
        uint denominator = reserveOut - amountOut;
        amountIn = (numerator / denominator) + 1;
    }

}