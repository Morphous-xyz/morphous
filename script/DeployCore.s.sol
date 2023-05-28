// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import "src/Morphous.sol";
import "src/Neo.sol";
import "src/FL.sol";

contract DeployCore is Script {
    FL internal fl;
    Neo internal neo;
    Morphous internal morphous;

    function run() public {
        uint256 deployer = vm.envUint("DEPLOYER_PK");
        address deployerAddress = vm.addr(deployer);

        // Utilize the `DEPLOYER_PK` env variable to deploy contracts.
        vm.startBroadcast(deployer);

        morphous = new Morphous(); // Ensure event `OwnershipTransferred` was emitted.
        if (morphous.owner() != deployerAddress) {
            revert("!owner");
        }
        fl = new FL(address(morphous));
        neo = new Neo(address(morphous), address(fl));

        vm.stopBroadcast();
    }
}
