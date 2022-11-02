// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "src/Morpheus.sol";
import "forge-std/Script.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast();
        console.log("Hello World");
        vm.stopBroadcast();
    }
}
