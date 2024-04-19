// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import { Test } from "forge-std/Test.sol";

contract Accounts is Test {
  // Default token owner
  Account public ALICE;
  // Other token owner
  Account public BOB;
  // Default approved operator
  Account public OPERATOR;
  // Default transaction recipient
  Account public RECIPIENT;
  // Default treasury
  Account public TREASURY;
  // Default royalty recipient
  Account public ROYALTY_RECIPIENT;
  // Whitelist signer
  Account public SIGNER;
  // Whitelist forger
  Account public FORGER;

  /// @dev Generates a user, labels its address, and funds it with test assets.
  function _createUser(string memory name) internal returns (Account memory account) {
    account = makeAccount(name);
    vm.deal({ account: account.addr, newBalance: 100 ether });
  }
}

contract ContractHelper {
  function _isContract(address account) internal view returns (bool) {
    uint256 _size_;
    assembly {
      _size_ := extcodesize(account)
    }
    return _size_ > 0;
  }
}

abstract contract TestHelper is Accounts, ContractHelper {
  function setUp() public virtual {
    ALICE = _createUser("Alice");
    BOB = _createUser("Bob");
    OPERATOR = _createUser("Operator");
    RECIPIENT = _createUser("Recipient");
    TREASURY = _createUser("Treasury");
    ROYALTY_RECIPIENT = _createUser("RoyaltyRecipient");
    SIGNER = _createUser("Signer");
    FORGER = _createUser("Forger");
  }
}
