// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;


interface IBondingCurveFactory {
    function createCurve(address token, address migrator) external returns (address curve);
    function getCurve(address) external view returns (address);
}