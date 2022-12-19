// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "src/Neo.sol";
import "src/Morphous.sol";
import "src/actions/flashloan/FL.sol";

import "forge-std/Script.sol";

contract DeployScript is Script {
    FL internal fl;
    Neo internal neo;
    Morphous internal morphous;

    function run() public {
        vm.startBroadcast();

        morphous = new Morphous();
        fl = new FL(address(morphous));
        neo = new Neo(address(morphous), address(fl));

        vm.stopBroadcast();
    }
}
