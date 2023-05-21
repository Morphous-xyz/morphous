// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "src/Neo.sol";
import "src/modular/ModMorphous.sol";
import "src/FL.sol";
import "src/modular/Zion.sol";

import "forge-std/Script.sol";

contract DeployScriptMod is Script {
    FL internal fl;
    Neo internal neo;
    ModMorphous internal morphous;
    Zion internal zion;

    function run() public {
        vm.startBroadcast();

        zion = new Zion();
        morphous = new ModMorphous(zion);
        fl = new FL(address(morphous));
        neo = new Neo(address(morphous), address(fl));

        vm.stopBroadcast();
    }
}
