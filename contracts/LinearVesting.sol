// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./libraries/TransferHelper.sol";

contract LinearVesting {
    struct Beneficiary {
        uint256 totalAmount;
        uint256 released;
    }

    uint256 public immutable start;
    uint256 public immutable duration;
    address public immutable erc20;
    mapping(address => Beneficiary) public beneficiaries;
    address[] public beneficiaryAddresses;

    event ERC20Released(
        address indexed token,
        address indexed beneficiary,
        uint256 amount
    );

    constructor(
        address _erc20,
        address[] memory _beneficiaryAddresses,
        uint256[] memory _totalAmounts,
        uint256 _duration
    ) {
        require(
            _beneficiaryAddresses.length == _totalAmounts.length,
            "Mismatched lengths"
        );
        require(_duration != 0, "Duration must be positive");

        for (uint256 i = 0; i < _beneficiaryAddresses.length; i++) {
            require(
                _beneficiaryAddresses[i] != address(0),
                "Beneficiary is the zero address"
            );
            require(
                _totalAmounts[i] != 0,
                "Total amount must be positive"
            );

            beneficiaries[_beneficiaryAddresses[i]] = Beneficiary({
                totalAmount: _totalAmounts[i],
                released: 0
            });
            beneficiaryAddresses.push(_beneficiaryAddresses[i]);
        }
        start = block.timestamp;
        duration = _duration;
        erc20 = _erc20;
    }

    function release() external {
        uint256 unreleased = _release(msg.sender);
    }

    function releaseAllUser() external {
        uint256 unreleased = 0;

        for (uint256 i = 0; i < beneficiaryAddresses.length; i++) {
            address beneficiary = beneficiaryAddresses[i];
            unreleased += _release(beneficiary);
        }
    }

    function _release(address to) private returns (uint256 unreleased) {
        Beneficiary storage beneficiary = beneficiaries[to];
        require(
            beneficiary.totalAmount > 0,
            "No vesting for this address"
        );

        unreleased = _releasableAmount(beneficiary);
        require(unreleased > 0, "No tokens are due");

        beneficiary.released += unreleased;
        // Assume you have an ERC20 token instance to transfer tokens
        // token.transfer(msg.sender, unreleased);
        TransferHelper.safeTransfer(erc20, to, unreleased);
        emit ERC20Released(erc20, to, unreleased);
    }

    function _releasableAmount(
        Beneficiary storage beneficiary
    ) private view returns (uint256) {
        if (block.timestamp < start) {
            return 0;
        } else if (block.timestamp >= start + duration) {
            return beneficiary.totalAmount - beneficiary.released;
        } else {
            uint256 timeElapsed = block.timestamp - start;
            uint256 totalVested = (beneficiary.totalAmount * timeElapsed) /
                duration;
            return totalVested - beneficiary.released;
        }
    }
}
