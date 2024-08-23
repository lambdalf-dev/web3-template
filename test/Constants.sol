// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

contract Constants {
  string public constant NAME = "NFT Collection";
  string public constant SYMBOL = "NFT";
  string public constant BASE_URI = "https://api.example.com/";
  string public constant NEW_BASE_URI = "https://example.com/api/";
  uint256 public constant FIRST_TOKEN = 1;
  uint256 public constant TARGET_TOKEN = 4;
  uint256 public constant TARGET_INDEX = 3;
  uint256 public constant BOB_TOKEN = 7;
  uint256 public constant ALICE_INIT_SUPPLY = 6;
  uint256 public constant ALICE_MORE_SUPPLY = 3;
  uint256 public constant ALICE_SUPPLY = ALICE_INIT_SUPPLY + ALICE_MORE_SUPPLY;
  uint256 public constant BOB_SUPPLY = 1;
  uint256 public constant MINTED_SUPPLY = ALICE_SUPPLY + BOB_SUPPLY;
  uint256 public constant BURNED_SUPPLY = 1;
  uint256 public constant DEFAULT_SERIES = 0;
  uint256 public constant SERIES_ID = 1;
  uint256 public constant TARGET_AMOUNT = 2;
  uint256 public constant MAX_BATCH = 10;
  uint256 public constant MAX_SUPPLY = 5000;
  uint256 public constant RESERVE = 20;
  uint256 public constant PRIVATE_SALE_PRICE = 1_000_000_000_000_000_000;
  uint256 public constant PUBLIC_SALE_PRICE = 2_000_000_000_000_000_000;
  uint96 public constant ROYALTY_BASE = 10_000;
  uint96 public constant ROYALTY_RATE = 100;
  bytes4 public constant RETVAL = 0x000d0b74;
  bytes public constant DATA = "0x000d0b7417742123dfd8";
  uint8 public constant WHITELIST_ID_CLAIM = 1;
  uint8 public constant WHITELIST_ID_PRIVATE_SALE = 2;
  uint256 public constant ALLOCATED = 5;
  uint256 public constant WHITELIST_CONSUMED = 1;
}
