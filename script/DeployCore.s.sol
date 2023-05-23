// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import "src/Morphous.sol";
import "src/Neo.sol";
import "src/FL.sol";

contract DeployCore is Script {
    FL internal fl;
    Neo internal neo;
    Morphous internal morphous;

    function run() public {
        // Utilize the `DEPLOYER_PK` env variable to deploy contracts.
        vm.startBroadcast(vm.envUint("DEPLOYER_PK"));

        morphous = new Morphous(); // Ensure event `OwnershipTransferred` was emitted.
        if (morphous.owner() != address(this)) {
            revert("!owner");
        }
        fl = new FL(address(morphous));
        neo = new Neo(address(morphous), address(fl));

        vm.stopBroadcast();
    }
}
