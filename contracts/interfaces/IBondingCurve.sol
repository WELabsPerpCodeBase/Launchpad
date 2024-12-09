// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IBondingCurve {
    function initialize(address token0, address migrator) external;
    function buy(uint256 amount, uint256 maxEthCost) external payable;
    function sell(uint256 amount, uint256 minEthOutput) external;
    function removeLiquidity() external;
    function migrateToken() external returns (uint256 amount);
    function token() external returns (address);
}