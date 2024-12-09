// SPDX-License-Identifier: MIT 
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ERC20Token is ERC20, AccessControl{

    bytes32 private constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    string private _url;

    constructor(string memory name_, string memory symbol_, string memory url_) 
        ERC20(name_, symbol_)
    {
       _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
       _grantRole(MINT_ADMIN_ROLE, msg.sender);
        _url = url_;
    }

    function url() external view returns (string memory) {
        return _url;
    }

    function mint(address to, uint amount) external onlyRole(MINT_ADMIN_ROLE) {
        _mint(to, amount);
    }
}