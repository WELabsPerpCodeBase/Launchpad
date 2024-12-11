// SPDX-License-Identifier: MIT 
pragma solidity >=0.8.0;

import "./libraries/TransferHelper.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IBondingCurve.sol";
import "./libraries/BondingCurveLibrary.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BondingCurve is ReentrancyGuard, IBondingCurve {

    address public immutable factory;
    address public migrator;
    address public token; // meme token

    uint256 private reserve0 = 1073000191 ether;
    uint256 private reserve1 = 1.5 ether;
    uint256 public constant rate = 2096; // test = 6000; default = 2096
    bool public isMarketCapReached;
    uint256 private initialized;

    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);
    event RemoveLiquidity(uint256 tokenAmount, uint256 ehter);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token, address _migrator) external {
        require(msg.sender == factory, 'FORBIDDEN');
        require(initialized == 0, 'already initialized');
        require(_token != address(0), 'zero address');
        token = _token;
        migrator = _migrator;
        initialized = 1;
    }

    function getReserves() external view returns (uint, uint) {
        return (reserve0, reserve1);
    }

    // buy meme token
    // amount = meme token out amount
    function buy(uint256 amountOut, uint256 maxEthCost) external payable nonReentrant {
        require(!isMarketCapReached, "Market Cap reached");
        uint256 amountDiff = IERC20(token).balanceOf(address(this)) - amountOut;
        require(amountDiff > 0, "only 10,000,000,000");
        // check if the meme token is reached the market cap
        if (amountDiff < _migrateToken()) {
            amountOut = IERC20(token).balanceOf(address(this)) - _migrateToken();
            isMarketCapReached = true;
        }

        uint ethIn = BondingCurveLibrary.getAmountIn(amountOut, reserve1, reserve0);
        require(ethIn <= maxEthCost, "Cost ETH too high");

        TransferHelper.safeTransfer(token, msg.sender, amountOut);
        TransferHelper.safeTransferETH(msg.sender, msg.value - ethIn);
        _update(reserve0 - amountOut, reserve1 + ethIn);
        emit Swap(msg.sender, 0, ethIn, amountOut, 0, msg.sender);
    }

    function sell(uint256 amountIn, uint256 minEthOut) external nonReentrant {
        require(!isMarketCapReached, "Market Cap reached");
        
        uint ethOut = BondingCurveLibrary.getAmountOut(amountIn, reserve0, reserve1);
        require(ethOut >= minEthOut, "Get ETH too low");
        require(ethOut <= address(this).balance, "Not enough ETH");
        
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amountIn);
        TransferHelper.safeTransferETH(msg.sender, ethOut);
        _update(reserve0 + amountIn, reserve1 - ethOut);
        emit Swap(msg.sender, amountIn, 0, 0, ethOut, msg.sender);
    }

    function _update(uint reserve0_, uint reserve1_) internal {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
        emit Sync(reserve0, reserve1);
    }


    function migrateToken() public pure returns (uint256 amount) {
        return _migrateToken();
    }

    function _migrateToken() internal pure returns (uint256 amount) {
        amount = 1e9 * rate * 10 ** 18 / 1e4  ;
    }

    function removeLiquidity() external  {
        require(msg.sender == migrator, "migrator required");
        require(isMarketCapReached, "Market Cap not reach");
        
        TransferHelper.safeTransfer(token, migrator, _migrateToken());
        
        uint eth = address(this).balance;
        TransferHelper.safeTransferETH(migrator, eth);

        emit RemoveLiquidity(_migrateToken(), eth);
    }
}