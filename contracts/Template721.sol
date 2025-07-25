// SPDX-License-Identifier: MIT

/**
 * Author: Lambdalf the White
 */
pragma solidity >=0.8.4 <0.9.0;

import { IArrays } from "@lambdalf-dev/src/interfaces/IArrays.sol";
import { IERC721 } from "@lambdalf-dev/src/interfaces/IERC721.sol";
import { IERC721Enumerable } from "@lambdalf-dev/src/interfaces/IERC721Enumerable.sol";
import { IERC721Metadata } from "@lambdalf-dev/src/interfaces/IERC721Metadata.sol";
import { IERC173 } from "@lambdalf-dev/src/interfaces/IERC173.sol";
import { IERC165 } from "@lambdalf-dev/src/interfaces/IERC165.sol";
import { IERC2981 } from "@lambdalf-dev/src/interfaces/IERC2981.sol";
import { ITemplate } from "./ITemplate.sol";

import { ERC721Batch } from "@lambdalf-dev/src/tokens/ERC721/ERC721Batch.sol";
import { ERC173 } from "@lambdalf-dev/src/utils/ERC173.sol";
import { ERC2981 } from "@lambdalf-dev/src/utils/ERC2981.sol";
import { Whitelist } from "@lambdalf-dev/src/utils/Whitelist.sol";

contract Template721 is IERC165, ERC721Batch, ERC173, ERC2981, Whitelist, IArrays, ITemplate {
  // **************************************
  // *****         DATA TYPES         *****
  // **************************************
  /// @dev A list of valid states
  enum ContractState {
    PAUSED,
    CLAIM,
    PRIVATE_SALE,
    PUBLIC_SALE
  }
  // **************************************

  // **************************************
  // *****    BYTECODE  VARIABLES     *****
  // **************************************
  /// @dev The maximum number of tokens that can be purchased at once in PUBLIC_SALE.
  uint256 public constant MAX_BATCH = 10;
  // **************************************

  // **************************************
  // *****     STORAGE VARIABLES      *****
  // **************************************
  /// @dev The current contract state.
  ContractState public contractState;
  /// @dev The max supply of NFTs.
  uint256 public maxSupply;
  /// @dev Amount of NFTs reserved for team mint.
  uint256 public reserve;
  /// @dev Address that will receive mint funds.
  address public treasury;
  /// @dev Sale phase mapped to sale price.
  mapping(ContractState => uint256) public salePrice;
  // **************************************

  // solhint-disable-next-line func-name-mixedcase
  constructor(
    uint256 maxSupply_,
    uint256 reserve_,
    uint256 privateSalePrice_,
    uint256 publicSalePrice_,
    uint96 royaltyRate_,
    address royaltyRecipient_,
    address treasury_,
    address adminSigner_
  )
    ERC721Batch("NFT Collection", "NFT")
    ERC173(msg.sender)
    ERC2981(royaltyRecipient_, royaltyRate_)
  {
    maxSupply = maxSupply_;
    reserve = reserve_;
    salePrice[ContractState.PRIVATE_SALE] = privateSalePrice_;
    salePrice[ContractState.PUBLIC_SALE] = publicSalePrice_;
    treasury = treasury_;
    _setWhitelist(adminSigner_);
  }

  // **************************************
  // *****           PUBLIC           *****
  // **************************************
  /// @dev Claims `qty_` tokens and transfers them to the caller.
  ///
  /// @param qty_ the amount of tokens to be minted
  /// @param alloted_ the maximum alloted for that user
  /// @param proof_ the signature to verify whitelist allocation
  ///
  /// Requirements:
  ///
  /// - Sale state must be {CLAIM}.
  /// - There must be enough tokens left to mint outside of the reserve.
  /// - Caller must be allowed to mint up to `qty_` tokens in private sale.
  function claim(uint256 qty_, uint256 alloted_, Proof calldata proof_) public {
    if (contractState != ContractState.CLAIM) {
      revert CONTRACT_STATE_INCORRECT();
    }
    if (qty_ == 0) {
      revert NFT_INVALID_QTY();
    }
    uint256 _remainingSupply_ = maxSupply - reserve - totalSupply();
    if (qty_ > _remainingSupply_) {
      revert NFT_MINTED_OUT();
    }
    uint256 _remainingAllocation_ = checkWhitelistAllowance(msg.sender, uint8(ContractState.CLAIM), alloted_, proof_);
    if (_remainingAllocation_ < qty_) {
      revert WHITELIST_FORBIDDEN();
    }
    _consumeWhitelist(msg.sender, uint8(ContractState.CLAIM), qty_);
    _mint(msg.sender, qty_);
  }
  /// @dev Purchases `qty_` tokens at private sale price and transfers them to the caller.
  ///
  /// @param qty_ the amount of tokens to be minted
  /// @param alloted_ the maximum alloted for that user
  /// @param proof_ the signature to verify whitelist allocation
  ///
  /// Requirements:
  ///
  /// - Sale state must be {PRIVATE_SALE}.
  /// - There must be enough tokens left to mint outside of the reserve.
  /// - Caller must send enough ether to pay for `qty_` tokens at private sale price.
  /// - Caller must be allowed to mint up to `qty_` tokens in private sale.

  function privateMint(uint256 qty_, uint256 alloted_, Proof calldata proof_) public payable {
    if (contractState != ContractState.PRIVATE_SALE) {
      revert CONTRACT_STATE_INCORRECT();
    }
    if (qty_ == 0) {
      revert NFT_INVALID_QTY();
    }
    uint256 _remainingSupply_ = maxSupply - reserve - totalSupply();
    if (qty_ > _remainingSupply_) {
      revert NFT_MINTED_OUT();
    }
    uint256 _expected_ = qty_ * salePrice[ContractState.PRIVATE_SALE];
    if (msg.value != _expected_) {
      revert ETHER_INCORRECT_PRICE();
    }
    uint256 _remainingAllocation_ =
      checkWhitelistAllowance(msg.sender, uint8(ContractState.PRIVATE_SALE), alloted_, proof_);
    if (_remainingAllocation_ < qty_) {
      revert WHITELIST_FORBIDDEN();
    }
    _consumeWhitelist(msg.sender, uint8(ContractState.PRIVATE_SALE), qty_);
    _mint(msg.sender, qty_);
  }
  /// @dev Purchases `qty_` tokens at public sale price and transfers them to the caller.
  ///
  /// @param qty_ the amount of tokens to be minted
  ///
  /// Requirements:
  ///
  /// - Sale state must be {PUBLIC_SALE}.
  /// - `qty_` must be lower than {MAX_BATCH}.
  /// - There must be enough tokens left to mint outside of the reserve.
  /// - Caller must send enough ether to pay for `qty_` tokens at public sale price.

  function publicMint(uint256 qty_) public payable {
    if (contractState != ContractState.PUBLIC_SALE) {
      revert CONTRACT_STATE_INCORRECT();
    }
    if (qty_ == 0) {
      revert NFT_INVALID_QTY();
    }
    if (qty_ > MAX_BATCH) {
      revert NFT_MAX_BATCH();
    }
    uint256 _remainingSupply_ = maxSupply - reserve - totalSupply();
    if (qty_ > _remainingSupply_) {
      revert NFT_MINTED_OUT();
    }
    uint256 _expected_ = qty_ * salePrice[ContractState.PUBLIC_SALE];
    if (msg.value != _expected_) {
      revert ETHER_INCORRECT_PRICE();
    }
    _mint(msg.sender, qty_);
  }
  // **************************************

  // **************************************
  // *****       CONTRACT_OWNER       *****
  // **************************************
  /// @notice Mints `amounts_` tokens and transfers them to `accounts_`.
  ///
  /// @param accounts_ the list of accounts that will receive airdropped tokens
  /// @param amounts_ the amount of tokens each account will receive
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  /// - `accounts_` and `amounts_` must have the same length.
  /// - There must be enough tokens left in the reserve.
  function airdrop(address[] memory accounts_, uint256[] memory amounts_) public onlyOwner {
    uint256 _len_ = accounts_.length;
    if (_len_ != amounts_.length) {
      revert ARRAY_LENGTH_MISMATCH();
    }
    uint256 _count_;
    uint256 _totalQty_;
    while (_count_ < _len_) {
      _totalQty_ += amounts_[_count_];
      _mint(accounts_[_count_], amounts_[_count_]);
      unchecked {
        ++_count_;
      }
    }
    if (_totalQty_ > reserve) {
      revert NFT_MAX_RESERVE();
    }
    unchecked {
      reserve -= _totalQty_;
    }
  }
  /// @notice Reduces the reserve.
  ///
  /// @param newReserve_ the new reserve
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  /// - `newReserve_` must be lower than `reserve`.

  function reduceReserve(uint256 newReserve_) public onlyOwner {
    if (newReserve_ >= reserve) {
      revert NFT_INVALID_RESERVE();
    }
    reserve = newReserve_;
  }
  /// @notice Reduces the max supply.
  ///
  /// @param newMaxSupply_ the new max supply
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  /// - `newMaxSupply_` must be lower than `maxSupply`.
  /// - `newMaxSupply_` must be higher than current supply + `reserve`.

  function reduceSupply(uint256 newMaxSupply_) public onlyOwner {
    if (newMaxSupply_ >= maxSupply || newMaxSupply_ < totalSupply() + reserve) {
      revert NFT_INVALID_SUPPLY();
    }
    maxSupply = newMaxSupply_;
  }
  /// @dev Updates the contract state.
  ///
  /// @param newState_ the new sale state
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  /// - `newState_` must be a valid state.

  function setContractState(ContractState newState_) public onlyOwner {
    ContractState _previousState_ = contractState;
    contractState = newState_;
    emit ContractStateChanged(uint8(_previousState_), uint8(newState_));
  }
  /// @notice Updates the royalty recipient and rate.
  ///
  /// @param newPrivatePrice_ the new private price
  /// @param newPublicPrice_ the new public price
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.

  function setPrices(uint256 newPrivatePrice_, uint256 newPublicPrice_) public onlyOwner {
    salePrice[ContractState.PRIVATE_SALE] = newPrivatePrice_;
    salePrice[ContractState.PUBLIC_SALE] = newPublicPrice_;
  }
  /// @notice Updates the contract treasury.
  ///
  /// @param newTreasury_ the new trasury
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.

  function setTreasury(address newTreasury_) public onlyOwner {
    treasury = newTreasury_;
  }
  /// @notice Withdraws all the money stored in the contract and sends it to the treasury.
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  /// - `treasury` must be able to receive the funds.
  /// - Contract must have a positive balance.

  function withdraw() public onlyOwner {
    uint256 _balance_ = address(this).balance;
    if (_balance_ == 0) {
      revert ETHER_NO_BALANCE();
    }

    // solhint-disable-next-line
    (bool _success_,) = payable(treasury).call{ value: _balance_ }("");
    if (!_success_) {
      revert ETHER_TRANSFER_FAIL();
    }
  }

  // *******************
  // * IERC721Metadata *
  // *******************
  /// @notice Updates the baseUri for the tokens.
  ///
  /// @param newBaseUri_ the new baseUri for the tokens
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  function setBaseUri(string memory newBaseUri_) public onlyOwner {
    _setBaseUri(newBaseUri_);
  }
  // *******************

  // ************
  // * IERC2981 *
  // ************
  /// @dev Sets the royalty rate to `newRoyaltyRate_` and the royalty recipient to `newRoyaltyRecipient_`.
  ///
  /// @param newRoyaltyRecipient_ the address that will receive royalty payments
  /// @param newRoyaltyRate_ the percentage of the sale price that will be taken off as royalties,
  ///   expressed in Basis Points (100 BP = 1%)
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  /// - `newRoyaltyRate_` cannot be higher than {ROYALTY_BASE};
  function setRoyaltyInfo(address newRoyaltyRecipient_, uint96 newRoyaltyRate_) public onlyOwner {
    _setRoyaltyInfo(newRoyaltyRecipient_, newRoyaltyRate_);
  }
  // ************

  // *************
  // * Whitelist *
  // *************
  /// @notice Updates the whitelist signer.
  ///
  /// @param newAdminSigner_ the new whitelist signer
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  function setWhitelist(address newAdminSigner_) public onlyOwner {
    _setWhitelist(newAdminSigner_);
  }
  // *************
  // **************************************

  // **************************************
  // *****            VIEW            *****
  // **************************************
  // ***********
  // * IERC165 *
  // ***********
  /// @dev Query if a contract implements an interface.
  /// @dev see https://eips.ethereum.org/EIPS/eip-165
  ///
  /// @param interfaceId_ the interface identifier, as specified in ERC-165
  ///
  /// @return bool true if the contract implements the specified interface, false otherwise
  ///
  /// Requirements:
  ///
  /// - This function must use less than 30,000 gas.
  function supportsInterface(bytes4 interfaceId_) public pure override returns (bool) {
    return interfaceId_ == type(IERC721).interfaceId || interfaceId_ == type(IERC721Enumerable).interfaceId
      || interfaceId_ == type(IERC721Metadata).interfaceId || interfaceId_ == type(IERC173).interfaceId
      || interfaceId_ == type(IERC165).interfaceId || interfaceId_ == type(IERC2981).interfaceId;
  }
  // ***********
  // **************************************

  // **************************************
  // *****          FALLBACK          *****
  // **************************************
  fallback() external payable { } // solhint-disable no-empty-blocks
  receive() external payable { } // solhint-disable no-empty-blocks
    // **************************************
}
