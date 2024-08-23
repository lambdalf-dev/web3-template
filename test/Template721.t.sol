// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import { Template721 } from "../contracts/Template721.sol";
import { ITemplate } from "../contracts/ITemplate.sol";

import { Constants } from "./Constants.sol";
import { TestHelper } from "./TestHelper.sol";

import { IArrays } from "@lambdalf-dev/interfaces/IArrays.sol";
import { IWhitelist } from "@lambdalf-dev/interfaces/IWhitelist.sol";
import { IERC721Receiver } from "@lambdalf-dev/interfaces/IERC721Receiver.sol";
import { IERC721 } from "@lambdalf-dev/interfaces/IERC721.sol";
import { IERC721Enumerable } from "@lambdalf-dev/interfaces/IERC721Enumerable.sol";
import { IERC721Metadata } from "@lambdalf-dev/interfaces/IERC721Metadata.sol";
import { IERC173 } from "@lambdalf-dev/interfaces/IERC173.sol";
import { IERC165 } from "@lambdalf-dev/interfaces/IERC165.sol";
import { IERC2981 } from "@lambdalf-dev/interfaces/IERC2981.sol";
import { LibString } from "solady/src/utils/LibString.sol";

import { IERC173Events } from "@lambdalf-dev/mocks/events/IERC173Events.sol";
import { IERC721Events } from "@lambdalf-dev/mocks/events/IERC721Events.sol";
import { Mock_Invalid_Eth_Receiver } from "@lambdalf-dev/mocks/external/Mock_Invalid_Eth_Receiver.sol";
import { Mock_NonERC721Receiver } from "@lambdalf-dev/mocks/external/Mock_NonERC721Receiver.sol";
import { Mock_ERC721Receiver } from "@lambdalf-dev/mocks/external/Mock_ERC721Receiver.sol";

contract Deployed is TestHelper, Constants, ITemplate, IERC173Events, IERC721Events {
  bytes4[] public INTERFACES = [
    type(IERC721).interfaceId,
    type(IERC721Enumerable).interfaceId,
    type(IERC721Metadata).interfaceId,
    type(IERC173).interfaceId,
    type(IERC165).interfaceId,
    type(IERC2981).interfaceId
  ];

  Template721 testContract;

  function setUp() public virtual override {
    super.setUp();
    testContract = new Template721(
      MAX_SUPPLY,
      RESERVE,
      PRIVATE_SALE_PRICE,
      PUBLIC_SALE_PRICE,
      ROYALTY_RATE,
      ROYALTY_RECIPIENT.addr,
      TREASURY.addr,
      SIGNER.addr
    );
  }

  function _depleteSupplyFixture() internal {
    testContract.reduceSupply(RESERVE);
  }

  function _setClaimFixture() internal {
    testContract.setContractState(Template721.ContractState.CLAIM);
  }

  function _setPrivateSaleFixture() internal {
    testContract.setContractState(Template721.ContractState.PRIVATE_SALE);
  }

  function _setPublicSaleFixture() internal {
    testContract.setContractState(Template721.ContractState.PUBLIC_SALE);
  }

  function _mintFixture() internal {
    _setPublicSaleFixture();
    vm.prank(ALICE.addr);
    vm.deal(ALICE.addr, ALICE_INIT_SUPPLY * PUBLIC_SALE_PRICE);
    testContract.publicMint{ value: ALICE_INIT_SUPPLY * PUBLIC_SALE_PRICE }(ALICE_INIT_SUPPLY);
    vm.prank(BOB.addr);
    vm.deal(BOB.addr, BOB_SUPPLY * PUBLIC_SALE_PRICE);
    testContract.publicMint{ value: BOB_SUPPLY * PUBLIC_SALE_PRICE }(BOB_SUPPLY);
    vm.prank(ALICE.addr);
    vm.deal(ALICE.addr, ALICE_MORE_SUPPLY * PUBLIC_SALE_PRICE);
    testContract.publicMint{ value: ALICE_MORE_SUPPLY * PUBLIC_SALE_PRICE }(ALICE_MORE_SUPPLY);
  }

  function _removeWhitelistFixture() internal {
    testContract.setWhitelist(address(0));
  }

  function _consumeClaimAllowanceFixture(
    address account,
    uint256 amount,
    uint256 alloted,
    IWhitelist.Proof memory proof
  )
    internal
  {
    _setClaimFixture();
    vm.prank(ALICE.addr);
    testContract.claim(amount, alloted, proof);
  }

  function _consumePrivateSaleAllowanceFixture(
    address account,
    uint256 amount,
    uint256 alloted,
    IWhitelist.Proof memory proof
  )
    internal
  {
    _setPrivateSaleFixture();
    uint256 price = amount * PRIVATE_SALE_PRICE;
    vm.deal(account, price);
    vm.prank(ALICE.addr);
    testContract.privateMint{ value: price }(amount, alloted, proof);
  }

  function _createProof(
    uint8 whitelistId,
    uint256 allotted,
    address account,
    Account memory signer
  )
    internal
    view
    returns (IWhitelist.Proof memory proof)
  {
    (uint8 v, bytes32 r, bytes32 s) =
      vm.sign(uint256(signer.key), keccak256(abi.encode(block.chainid, whitelistId, allotted, account)));
    return IWhitelist.Proof(r, s, v);
  }
}

// **************************************
// *****          FALLBACK          *****
// **************************************
contract Unit_Fallback is Deployed {
  function test_unit_fallback() public {
    uint256 initialBalance = address(testContract).balance;
    vm.expectRevert();
    (bool success,) = payable(address(testContract)).call{ value: 10 }(DATA);
  }

  function test_unit_receive() public {
    uint256 initialBalance = address(testContract).balance;
    vm.expectRevert();
    (bool success,) = payable(address(testContract)).call{ value: 10 }("");
  }
}
// **************************************

// **************************************
// *****           PUBLIC           *****
// **************************************
// ***************
// * Template721 *
// ***************
contract Unit_Claim is Deployed {
  function test_unit_claim_revert_when_contract_state_is_paused() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED;
    uint256 amount = WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    vm.prank(operator);
    vm.expectRevert(ITemplate.CONTRACT_STATE_INCORRECT.selector);
    testContract.claim(amount, alloted, proof);
  }

  function test_unit_claim_revert_when_quantity_requested_is_zero() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED;
    uint256 amount = 0;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    _setClaimFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.NFT_INVALID_QTY.selector);
    testContract.claim(amount, alloted, proof);
  }

  function test_unit_claim_revert_when_supply_is_depleted() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED;
    uint256 amount = WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    _depleteSupplyFixture();
    _setClaimFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.NFT_MINTED_OUT.selector);
    testContract.claim(amount, alloted, proof);
  }

  function test_unit_claim_revert_when_requesting_more_than_allocated() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED;
    uint256 amount = alloted + WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    _setClaimFixture();
    vm.prank(operator);
    vm.expectRevert(IWhitelist.WHITELIST_FORBIDDEN.selector);
    testContract.claim(amount, alloted, proof);
  }

  function test_unit_claim_emit_Transfer_events() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED;
    uint256 amount = alloted;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    _setClaimFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.claim(amount, alloted, proof);
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
    assertEq(
      testContract.checkWhitelistAllowance(operator, whitelistId, alloted, proof), alloted - amount, "invalid allowance"
    );
  }
}

contract Fuzz_Claim is Deployed {
  function test_fuzz_claim_emit_Transfer_events(uint256 amount) public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED;
    amount = bound(amount, 1, alloted);
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    _setClaimFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.claim(amount, alloted, proof);
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
    assertEq(
      testContract.checkWhitelistAllowance(operator, whitelistId, alloted, proof), alloted - amount, "invalid allowance"
    );
  }
}

contract Edge_Claim is Deployed {
  function test_edge_claim_revert_when_minting_more_than_supply() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED + 1;
    uint256 amount = WHITELIST_CONSUMED + 1;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    testContract.reduceSupply(RESERVE + WHITELIST_CONSUMED);
    _setClaimFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.NFT_MINTED_OUT.selector);
    testContract.claim(amount, alloted, proof);
  }

  function test_edge_claim_emit_Transfer_event_when_minting_the_whole_supply() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED;
    uint256 amount = WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    testContract.reduceSupply(RESERVE + amount);
    _setClaimFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.claim(amount, alloted, proof);
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
    assertEq(
      testContract.checkWhitelistAllowance(operator, whitelistId, alloted, proof), alloted - amount, "invalid allowance"
    );
  }
}

contract Unit_PrivateMint is Deployed {
  function test_unit_revert_when_contract_state_is_paused() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    uint256 amount = WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    vm.prank(operator);
    vm.expectRevert(ITemplate.CONTRACT_STATE_INCORRECT.selector);
    testContract.privateMint{ value: price }(amount, alloted, proof);
  }

  function test_unit_revert_when_contract_state_is_public_sale() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    uint256 amount = WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    _setPublicSaleFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.CONTRACT_STATE_INCORRECT.selector);
    testContract.privateMint{ value: price }(amount, alloted, proof);
  }

  function test_unit_revert_when_quantity_requested_is_zero() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    uint256 amount = 0;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    _setPrivateSaleFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.NFT_INVALID_QTY.selector);
    testContract.privateMint(0, alloted, proof);
  }

  function test_unit_revert_when_supply_is_depleted() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    uint256 amount = WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    _depleteSupplyFixture();
    _setPrivateSaleFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.NFT_MINTED_OUT.selector);
    testContract.privateMint{ value: price }(amount, alloted, proof);
  }

  function test_unit_revert_when_incorrect_amount_of_ether_sent() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    uint256 amount = WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    _setPrivateSaleFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.ETHER_INCORRECT_PRICE.selector);
    testContract.privateMint(amount, alloted, proof);
  }

  function test_unit_revert_when_requesting_more_than_allocated() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    uint256 amount = alloted + WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    _setPrivateSaleFixture();
    vm.prank(operator);
    vm.expectRevert(IWhitelist.WHITELIST_FORBIDDEN.selector);
    testContract.privateMint{ value: price }(amount, alloted, proof);
  }

  function test_unit_emit_Transfer_events() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    uint256 amount = alloted;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    _setPrivateSaleFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.privateMint{ value: price }(amount, alloted, proof);
    assertEq(address(testContract).balance, price, "invalid contract ether balance");
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
    assertEq(
      testContract.checkWhitelistAllowance(operator, whitelistId, alloted, proof), alloted - amount, "invalid allowance"
    );
  }
}

contract Fuzz_PrivateMint is Deployed {
  function test_fuzz_private_mint_emit_Transfer_events(uint256 amount) public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    amount = bound(amount, 1, alloted);
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    _setPrivateSaleFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.privateMint{ value: price }(amount, alloted, proof);
    assertEq(address(testContract).balance, price, "invalid contract ether balance");
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
    assertEq(
      testContract.checkWhitelistAllowance(operator, whitelistId, alloted, proof), alloted - amount, "invalid allowance"
    );
  }
}

contract Edge_PrivateMint is Deployed {
  function test_edge_emit_Transfer_event_when_minting_the_whole_supply() public {
    address operator = ALICE.addr;
    uint8 whitelistId = WHITELIST_ID_PRIVATE_SALE;
    uint256 alloted = ALLOCATED;
    uint256 amount = WHITELIST_CONSUMED;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    uint256 price = amount * PRIVATE_SALE_PRICE;
    testContract.reduceSupply(RESERVE + amount);
    _setPrivateSaleFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.privateMint{ value: price }(amount, alloted, proof);
    assertEq(address(testContract).balance, price, "invalid contract ether balance");
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
    assertEq(
      testContract.checkWhitelistAllowance(operator, whitelistId, alloted, proof), alloted - amount, "invalid allowance"
    );
  }
}

contract Unit_PublicMint is Deployed {
  function test_unit_revert_when_contract_state_is_paused() public {
    address operator = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    uint256 price = amount * PUBLIC_SALE_PRICE;
    vm.prank(operator);
    vm.expectRevert(ITemplate.CONTRACT_STATE_INCORRECT.selector);
    testContract.publicMint{ value: price }(amount);
  }

  function test_unit_revert_when_contract_state_is_private_sale() public {
    address operator = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    uint256 price = amount * PUBLIC_SALE_PRICE;
    _setPrivateSaleFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.CONTRACT_STATE_INCORRECT.selector);
    testContract.publicMint{ value: price }(amount);
  }

  function test_unit_revert_when_quantity_requested_is_zero() public {
    address operator = ALICE.addr;
    uint256 amount = 0;
    uint256 price = amount * PUBLIC_SALE_PRICE;
    _setPublicSaleFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.NFT_INVALID_QTY.selector);
    testContract.publicMint(amount);
  }

  function test_unit_revert_when_requesting_more_than_max_batch() public {
    address operator = ALICE.addr;
    uint256 amount = MAX_BATCH + TARGET_AMOUNT;
    uint256 price = amount * PUBLIC_SALE_PRICE;
    _setPublicSaleFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.NFT_MAX_BATCH.selector);
    testContract.publicMint{ value: price }(amount);
  }

  function test_unit_revert_when_supply_is_depleted() public {
    address operator = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    uint256 price = amount * PUBLIC_SALE_PRICE;
    _depleteSupplyFixture();
    _setPublicSaleFixture();
    vm.prank(operator);
    vm.expectRevert(ITemplate.NFT_MINTED_OUT.selector);
    testContract.publicMint{ value: price }(amount);
  }

  function test_unit_revert_when_incorrect_amount_of_ether_sent() public {
    address operator = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    uint256 price = amount * PUBLIC_SALE_PRICE;
    _setPublicSaleFixture();
    vm.expectRevert(ITemplate.ETHER_INCORRECT_PRICE.selector);
    testContract.publicMint(amount);
  }

  function test_unit_emit_Transfer_events() public {
    address operator = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    uint256 price = amount * PUBLIC_SALE_PRICE;
    _setPublicSaleFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.publicMint{ value: price }(amount);
    assertEq(address(testContract).balance, price, "invalid contract ether balance");
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
  }
}

contract Fuzz_PublicMint is Deployed {
  function test_fuzz_public_mint_emit_Transfer_events(uint256 amount) public {
    address operator = ALICE.addr;
    amount = bound(amount, 1, MAX_BATCH);
    uint256 price = amount * PUBLIC_SALE_PRICE;
    _setPublicSaleFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.publicMint{ value: price }(amount);
    assertEq(address(testContract).balance, price, "invalid contract ether balance");
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
  }
}

contract Edge_PublicMint is Deployed {
  function test_edge_emit_Transfer_event_when_minting_the_whole_supply() public {
    address operator = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    uint256 price = amount * PUBLIC_SALE_PRICE;
    testContract.reduceSupply(RESERVE + amount);
    _setPublicSaleFixture();
    vm.prank(operator);
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), operator, i);
    }
    testContract.publicMint{ value: price }(amount);
    assertEq(address(testContract).balance, price, "invalid contract ether balance");
    assertEq(testContract.balanceOf(operator), amount, "invalid balance");
    assertEq(testContract.totalSupply(), amount, "invalid supply");
  }
}
// ***************
// **************************************

// **************************************
// *****       CONTRACT OWNER       *****
// **************************************
// ***************
// * Template721 *
// ***************
contract Unit_Airdrop is Deployed {
  function test_unit_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    address recipient = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    address[] memory addresses = new address[](1);
    addresses[0] = recipient;
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = amount;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.airdrop(addresses, amounts);
  }

  function test_unit_revert_when_array_lengths_dont_match() public {
    address recipient = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    address[] memory addresses = new address[](1);
    addresses[0] = recipient;
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = amount;
    amounts[1] = amount;
    vm.expectRevert(abi.encodeWithSelector(IArrays.ARRAY_LENGTH_MISMATCH.selector));
    testContract.airdrop(addresses, amounts);
  }

  function test_unit_revert_when_airdropping_more_than_the_reserve_to_one_user() public {
    address recipient = ALICE.addr;
    uint256 amount = RESERVE + 1;
    address[] memory addresses = new address[](1);
    addresses[0] = recipient;
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = amount;
    vm.expectRevert(ITemplate.NFT_MAX_RESERVE.selector);
    testContract.airdrop(addresses, amounts);
  }

  function test_unit_revert_when_airdropping_more_than_the_reserve_to_several_users() public {
    address recipient = ALICE.addr;
    uint256 amount = TARGET_AMOUNT;
    address[] memory addresses = new address[](2);
    addresses[0] = recipient;
    addresses[1] = BOB.addr;
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = amount;
    amounts[1] = RESERVE;
    vm.expectRevert(ITemplate.NFT_MAX_RESERVE.selector);
    testContract.airdrop(addresses, amounts);
  }

  function test_unit_emit_Transfer_events() public {
    address recipient1 = ALICE.addr;
    address recipient2 = BOB.addr;
    uint256 amount1 = TARGET_AMOUNT;
    uint256 amount2 = 1;
    address[] memory addresses = new address[](2);
    addresses[0] = recipient1;
    addresses[1] = recipient2;
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = amount1;
    amounts[1] = amount2;
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount1; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), recipient1, i);
    }
    for (uint256 i = FIRST_TOKEN + amount1; i < amount1 + amount2; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), recipient2, i);
    }
    testContract.airdrop(addresses, amounts);
    assertEq(testContract.balanceOf(recipient1), amount1, "invalid recipient1 balance");
    assertEq(testContract.balanceOf(recipient2), amount2, "invalid recipient2 balance");
    assertEq(testContract.totalSupply(), amount1 + amount2, "invalid supply");
    assertEq(testContract.reserve(), RESERVE - (amount1 + amount2), "invalid supply");
  }
}

contract Fuzz_Airdrop is Deployed {
  function test_fuzz_airdrop_emit_Transfer_events(uint256 amount1) public {
    address recipient1 = ALICE.addr;
    address recipient2 = BOB.addr;
    amount1 = bound(amount1, 1, RESERVE - 1);
    uint256 amount2 = 1;
    address[] memory addresses = new address[](2);
    addresses[0] = recipient1;
    addresses[1] = recipient2;
    uint256[] memory amounts = new uint256[](2);
    amounts[0] = amount1;
    amounts[1] = amount2;
    for (uint256 i = FIRST_TOKEN; i < FIRST_TOKEN + amount1; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), recipient1, i);
    }
    for (uint256 i = FIRST_TOKEN + amount1; i < amount1 + amount2; ++i) {
      vm.expectEmit(address(testContract));
      emit Transfer(address(0), recipient2, i);
    }
    testContract.airdrop(addresses, amounts);
    assertEq(testContract.balanceOf(recipient1), amount1, "invalid recipient1 balance");
    assertEq(testContract.balanceOf(recipient2), amount2, "invalid recipient2 balance");
    assertEq(testContract.totalSupply(), amount1 + amount2, "invalid supply");
    assertEq(testContract.reserve(), RESERVE - (amount1 + amount2), "invalid supply");
  }
}

contract Unit_ReduceReserve is Deployed {
  function test_unit_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    uint256 newReserve = 0;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.reduceReserve(newReserve);
  }

  function test_unit_revert_when_increasing_reserve() public {
    uint256 newReserve = RESERVE + 1;
    vm.expectRevert(ITemplate.NFT_INVALID_RESERVE.selector);
    testContract.reduceReserve(newReserve);
  }

  function test_unit_decrease_reserve_successfully() public {
    uint256 newReserve = 0;
    testContract.reduceReserve(newReserve);
    assertEq(testContract.reserve(), newReserve, "invalid reserve");
  }
}

contract Fuzz_ReduceReserve is Deployed {
  function test_fuzz_decrease_reserve_successfully(uint256 amount) public {
    amount = bound(amount, 0, RESERVE - 1);
    testContract.reduceReserve(amount);
    assertEq(testContract.reserve(), amount, "invalid reserve");
  }
}

contract Edge_ReduceReserve is Deployed {
  function test_edge_revert_when_not_changing_reserve() public {
    uint256 newReserve = RESERVE;
    vm.expectRevert(ITemplate.NFT_INVALID_RESERVE.selector);
    testContract.reduceReserve(newReserve);
  }
}

contract Unit_ReduceSupply is Deployed {
  function test_unit_reduceSupply_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    uint256 newSupply = RESERVE;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.reduceSupply(newSupply);
  }

  function test_unit_reduceSupply_revert_when_increasing_supply() public {
    uint256 newSupply = MAX_SUPPLY + 1;
    vm.expectRevert(ITemplate.NFT_INVALID_SUPPLY.selector);
    testContract.reduceSupply(newSupply);
  }

  function test_unit_reduceSupply_decrease_supply_successfully() public {
    uint256 newSupply = RESERVE;
    testContract.reduceSupply(newSupply);
    assertEq(testContract.maxSupply(), newSupply, "invalid supply");
  }
}

contract Fuzz_ReduceSupply is Deployed {
  function test_fuzz_reduceSupply_decrease_supply_successfully(uint256 amount) public {
    amount = bound(amount, RESERVE, MAX_SUPPLY - 1);
    testContract.reduceSupply(amount);
    assertEq(testContract.maxSupply(), amount, "invalid supply");
  }
}

contract Edge_ReduceSupply is Deployed {
  function test_edge_reduceSupply_revert_when_not_changing_supply() public {
    uint256 newSupply = MAX_SUPPLY;
    vm.expectRevert(ITemplate.NFT_INVALID_SUPPLY.selector);
    testContract.reduceSupply(newSupply);
  }
}

contract Unit_SetContractState is Deployed {
  function test_unit_setContractState_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    uint8 newState = uint8(Template721.ContractState.CLAIM);
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.setContractState(Template721.ContractState(newState));
    assertEq(uint8(testContract.contractState()), uint8(Template721.ContractState.PAUSED), "invalid state");
  }

  function test_unit_setContractState_revert_when_new_state_is_invalid() public {
    uint8 newState = uint8(Template721.ContractState.PUBLIC_SALE) + 1;
    vm.expectRevert();
    testContract.setContractState(Template721.ContractState(newState));
    assertEq(uint8(testContract.contractState()), uint8(Template721.ContractState.PAUSED), "invalid state");
  }

  function test_unit_setContractState_emit_ContractStateChanged_event() public {
    uint8 newState = uint8(Template721.ContractState.CLAIM);
    vm.expectEmit(address(testContract));
    emit ContractStateChanged(uint8(Template721.ContractState.PAUSED), newState);
    testContract.setContractState(Template721.ContractState(newState));
    assertEq(uint8(testContract.contractState()), uint8(newState), "invalid state");
  }
}

contract Fuzz_SetContractState is Deployed {
  function test_fuzz_setContractState_emit_ContractStateChanged_event(uint8 newState) public {
    vm.assume(newState < uint8(Template721.ContractState.PUBLIC_SALE) + 1);
    vm.expectEmit(address(testContract));
    emit ContractStateChanged(uint8(Template721.ContractState.PAUSED), newState);
    testContract.setContractState(Template721.ContractState(newState));
    assertEq(uint8(testContract.contractState()), uint8(newState), "invalid state");
  }
}

contract Unit_SetPrices is Deployed {
  function test_unit_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    uint256 newDiscountPrice = 0;
    uint256 newPrice = 0;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.setPrices(newDiscountPrice, newPrice);
  }

  function test_unit_update_prices_accurately() public {
    uint256 newDiscountPrice = 0;
    uint256 newPrice = 0;
    testContract.setPrices(newDiscountPrice, newPrice);
    assertEq(testContract.salePrice(Template721.ContractState.PRIVATE_SALE), newDiscountPrice, "invalid private price");
    assertEq(testContract.salePrice(Template721.ContractState.PUBLIC_SALE), newPrice, "invalid public price");
  }
}

contract Unit_SetTreasury is Deployed {
  function test_unit_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    address newTreasury = RECIPIENT.addr;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.setTreasury(newTreasury);
  }

  function test_unit_update_treasury_successfully() public {
    address newTreasury = RECIPIENT.addr;
    testContract.setTreasury(newTreasury);
    assertEq(testContract.treasury(), newTreasury, "invalid treasury address");
  }
}

contract Unit_Withdraw is Deployed {
  function test_unit_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.withdraw();
  }

  function test_unit_revert_when_contract_holds_no_eth() public {
    vm.expectRevert(ITemplate.ETHER_NO_BALANCE.selector);
    testContract.withdraw();
  }

  function test_unit_revert_when_treasury_cant_receive_eth() public {
    _mintFixture();
    testContract.setTreasury(address(this));
    vm.expectRevert(ITemplate.ETHER_TRANSFER_FAIL.selector);
    testContract.withdraw();
  }

  function test_unit_eth_balance_transferred_successfully() public {
    _mintFixture();
    testContract.withdraw();
    assertEq(address(TREASURY.addr).balance, 100 ether + MINTED_SUPPLY * PUBLIC_SALE_PRICE, "invalid treasury balance");
    assertEq(address(testContract).balance, 0, "invalid contract balance");
  }
}
// ***************

// ************
// * IERC2981 *
// ************
contract Unit_SetRoyaltyInfo is Deployed {
  function test_unit_setRoyaltyInfo_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    address newRecipient = OPERATOR.addr;
    uint96 newRate = ROYALTY_RATE / 2;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.setRoyaltyInfo(newRecipient, newRate);
  }

  function test_unit_setRoyaltyInfo_setting_royalties() public {
    address newRecipient = OPERATOR.addr;
    uint96 newRate = ROYALTY_RATE / 2;
    uint256 tokenId = TARGET_TOKEN;
    uint256 price = PRIVATE_SALE_PRICE;
    address expectedRecipient = newRecipient;
    uint256 expectedAmount = price * newRate / ROYALTY_BASE;
    testContract.setRoyaltyInfo(newRecipient, newRate);
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }

  function test_unit_setRoyaltyInfo_removing_royalty_recipient() public {
    address newRecipient = address(0);
    uint96 newRate = ROYALTY_RATE / 2;
    uint256 tokenId = TARGET_TOKEN;
    uint256 price = PRIVATE_SALE_PRICE;
    address expectedRecipient = address(0);
    uint256 expectedAmount = 0;
    testContract.setRoyaltyInfo(newRecipient, newRate);
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }

  function test_unit_setRoyaltyInfo_removing_royalty_rate() public {
    address newRecipient = OPERATOR.addr;
    uint96 newRate = 0;
    uint256 tokenId = TARGET_TOKEN;
    uint256 price = PRIVATE_SALE_PRICE;
    address expectedRecipient = address(0);
    uint256 expectedAmount = 0;
    testContract.setRoyaltyInfo(newRecipient, newRate);
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }
}
// ************

// *******************
// * IERC721Metadata *
// *******************
contract Unit_SetBaseUri is Deployed {
  function test_unit_setBaseUri_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    string memory newBaseUri = NEW_BASE_URI;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.setBaseUri(newBaseUri);
  }

  function test_unit_setBaseUri_accurately_updates_uri() public {
    string memory newBaseUri = NEW_BASE_URI;
    uint256 tokenId = TARGET_TOKEN;
    _mintFixture();
    testContract.setBaseUri(newBaseUri);
    assertEq(
      keccak256(abi.encodePacked(testContract.tokenURI(tokenId))),
      keccak256(abi.encodePacked(newBaseUri, LibString.toString(tokenId))),
      "invalid uri"
    );
  }
}
// *******************

// *************
// * Whitelist *
// *************
contract Unit_SetWhitelist is Deployed {
  function test_unit_setWhitelist_revert_when_caller_is_not_contract_owner() public {
    address operator = OPERATOR.addr;
    vm.prank(operator);
    vm.expectRevert(IERC173.IERC173_NOT_OWNER.selector);
    testContract.setWhitelist(FORGER.addr);
  }

  function test_unit_setWhitelist_remove_whitelist() public {
    uint8 whitelistId = WHITELIST_ID_CLAIM;
    uint256 alloted = ALLOCATED;
    address account = ALICE.addr;
    address whitelistedAccount = ALICE.addr;
    IWhitelist.Proof memory proof = _createProof(whitelistId, alloted, whitelistedAccount, SIGNER);
    testContract.setWhitelist(address(0));
    vm.expectRevert(IWhitelist.WHITELIST_NOT_SET.selector);
    testContract.checkWhitelistAllowance(account, whitelistId, alloted, proof);
  }
}
// *************
// **************************************

// **************************************
// *****            VIEW            *****
// **************************************
// ***************
// * Template721 *
// ***************
contract Unit_ContractState is Deployed {
  function test_unit_contractState_is_paused() public {
    assertEq(uint8(testContract.contractState()), uint8(Template721.ContractState.PAUSED), "incorrect contract state");
  }
}

contract Unit_MaxSupply is Deployed {
  function test_unit_maxSupply_is_accurate() public {
    assertEq(testContract.maxSupply(), MAX_SUPPLY, "incorrect max supply");
  }
}
// ***************

// ***********
// * IERC165 *
// ***********
contract Unit_SupportsInterface is Deployed {
  function test_unit_supports_the_expected_interfaces() public {
    for (uint256 i; i < INTERFACES.length; ++i) {
      assertTrue(testContract.supportsInterface(INTERFACES[i]), "invalid interface");
    }
  }
}
// ***********
// **************************************
