// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./token/ERC20Token.sol";
import "./interfaces/IBondingCurveFactory.sol";
import "./interfaces/IMigrator.sol";
import "./interfaces/IBondingCurve.sol";
import "./LinearVesting.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/BondingCurveLibrary.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Launchpad is Ownable2Step {
    IBondingCurveFactory immutable curveFactory;
    IMigrator immutable migrator;
    address public feeTo;
    uint256 public constant MAX_CREATE_FEES = 0.01 ether;
    uint256 public createFees = 0.002 ether;
    uint256 public constant MAX_INITIAL_BUY = 5;

    event TokenLaunchpad(
        address indexed curve,
        address indexed token,
        address indexed user,
        string name,
        string symbol,
        string url
    );
    event InitialBuy(
        address indexed curve,
        address indexed user,
        address indexed vestaddr,
        uint256 duration,
        address[] beneficiaries,
        uint256[] amounts
    );
    // event TokenMigration(address user, address token, address curve);
    event FeeToUpdated(address indexed feeTo);
    event CreateFeesUpdated(uint256 createFees);

    constructor(
        address _curveFactory,
        address _migrator,
        address _feeTo
    ) Ownable(msg.sender) {
        curveFactory = IBondingCurveFactory(_curveFactory);
        migrator = IMigrator(_migrator);
        feeTo = _feeTo;
    }

    function setCreateFees(uint256 _fees) external onlyOwner {
        require(_fees < MAX_CREATE_FEES, "out of max create fees");
        createFees = _fees;
        emit CreateFeesUpdated(createFees);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        require(_feeTo != address(0), "Not a valid address");
        feeTo = _feeTo;
        emit FeeToUpdated(feeTo);
    }

    function _launchpad(
        string calldata name,
        string calldata symbol,
        string calldata url
    ) internal returns (address token, address curve) {
        ERC20Token erc20Token = new ERC20Token(name, symbol, url);
        token = address(erc20Token);
        curve = curveFactory.createCurve(token, address(migrator));
        erc20Token.mint(curve, 1e27);
        erc20Token.renounceRole(keccak256("MINT_ADMIN_ROLE"), address(this));
        emit TokenLaunchpad(curve, token, msg.sender, name, symbol, url);
    }

    // create new token
    function launchpad(
        string calldata name,
        string calldata symbol,
        string calldata url
    ) external payable returns (address token, address curve) {
        require(msg.value >= createFees, "Must send 0.001 ether");
        (token, curve) = _launchpad(name, symbol, url);
        TransferHelper.safeTransferETH(feeTo, createFees);
    }

    function launchpadInitialBuy(
        string calldata name,
        string calldata symbol,
        string calldata url,
        address[] calldata _beneficiaryAddresses,
        uint256[] calldata _totalAmounts,
        uint256 _duration,
        uint256 amount
    ) external payable returns (address token, address curve, address vesting) {
        require(amount != 0, "Amount must be greater than zero");
        uint256 buyValue = msg.value - createFees;
        require(buyValue != 0, "Must send some ether");
        require(_beneficiaryAddresses.length <= MAX_INITIAL_BUY, "reached the max");
        require(
            _beneficiaryAddresses.length == _totalAmounts.length,
            "BondingCurve: Mismatched lengths"
        );

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _beneficiaryAddresses.length; i++) {
            totalAmount += _totalAmounts[i];
        }
        require(totalAmount == amount, "Distribution inconsistency");

        (token, curve) = _launchpad(name, symbol, url);

        LinearVesting vesting_ = new LinearVesting(
            token,
            _beneficiaryAddresses,
            _totalAmounts,
            _duration
        );
        vesting = address(vesting_);
        uint256 pre = address(this).balance;
        IBondingCurve(curve).buy{value: buyValue}(amount, buyValue);
        TransferHelper.safeTransfer(token, address(vesting), amount);
        TransferHelper.safeTransferETH(feeTo, createFees);
        uint256 payback = msg.value - (pre - address(this).balance);
        TransferHelper.safeTransferETH(msg.sender, payback);

        emit InitialBuy(
            curve,
            msg.sender,
            vesting,
            _duration,
            _beneficiaryAddresses,
            _totalAmounts
        );
    }

    receive() external payable {}

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure virtual returns (uint amountOut) {
        return
            BondingCurveLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure virtual returns (uint amountIn) {
        return
            BondingCurveLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }
}
