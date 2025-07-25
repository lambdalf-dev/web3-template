pragma solidity 0.8.25;

import { Template721 } from "./../contracts/Template721.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

contract DeployScript is Script {
  function run() external {
    console2.log("Deploying Template721...");
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    uint256 maxSupply_ = vm.envUint("MAX_SUPPLY");
    uint256 reserve_ = vm.envUint("RESERVE");
    uint256 privateSalePrice_ = vm.envUint("PRIVATE_SALE_PRICE");
    uint256 publicSalePrice_ = vm.envUint("PUBLIC_SALE_PRICE");
    uint96 royaltyRate_ = uint96(vm.envUint("ROYALTY_RATE"));
    address royaltyRecipient_ = vm.envAddress("ROYALTY_RECIPIENT");
    address treasury_ = vm.envAddress("TREASURY");
    address adminSigner_ = vm.envAddress("SIGNER_ADDRESS");

    vm.startBroadcast(deployerPrivateKey);

    Template721 _contract = new Template721(
      maxSupply_,
      reserve_,
      privateSalePrice_,
      publicSalePrice_,
      royaltyRate_,
      royaltyRecipient_,
      treasury_,
      adminSigner_
    );
    console2.log("Deployed Template721 at address: ", address(_contract));

    vm.stopBroadcast();
  }
}
