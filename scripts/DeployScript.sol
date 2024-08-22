pragma solidity 0.8.25;

import { Foo } from "./../contracts/Foo.sol";
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployScript is Script {
  function run() external {
    console2.log("Deploying Foo...");
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);

    Foo _contract = new Foo();
    console2.log("Deployed Foo at address: ", address(_contract));

    vm.stopBroadcast();
  }
}
