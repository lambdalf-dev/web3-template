// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { console2 } from "forge-std/console2.sol";
import { TestHelper } from "./TestHelper.sol";

import { Foo } from "../src/Foo.sol";

contract Constants is TestHelper {
  uint256 public constant TARGET_INDEX = 3;
}

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract Deployed is Constants {
  Foo internal foo;

  /// @dev A function invoked before each test case is run.
  function setUp() public virtual override {
    // Instantiate the contract-under-test.
    foo = new Foo();
  }
}

contract Id is Deployed {
  /// @dev Basic test. Run it with `forge test -vvv` to see the console log.
  function test_unit_id() external {
    console2.log("Hello World");
    uint256 x = TARGET_INDEX;
    assertEq(foo.id(x), x, "value mismatch");
  }

  /// @dev Fuzz test that provides random values for an unsigned integer, but which rejects zero as an input.
  /// If you need more sophisticated input validation, you should use the `bound` utility instead.
  function test_fuzz_id(uint256 x) external {
    vm.assume(x != 0); // or x = bound(x, 1, 100)
    assertEq(foo.id(x), x, "value mismatch");
  }
}
