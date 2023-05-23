// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {AggregatorsModule} from "src/modules/AggregatorsModule.sol";
import {Logger} from "src/Logger.sol";
import {MorphoModule} from "src/modules/MorphoModule.sol";
import {Morphous, Constants} from "src/Morphous.sol";
import {TokenActionsModule} from "src/modules/TokenActionsModule.sol";

contract DeployModules is Script {
    Logger logger;
    AggregatorsModule aggregatorsModule;
    TokenActionsModule tokenActionsModule;
    MorphoModule morphoModule;
    Morphous morpheous = Morphous(payable(0x1234567890123456789012345678901234567890)); // Replace with the actual address of the deployed Morphous contract.

    function run() public {
        if (morpheous == Morphous(payable(0x1234567890123456789012345678901234567890))) {
            revert("Replace the address of the deployed Morphous contract.");
        }
        // Utilize the `DEPLOYER_PK` env variable to deploy contracts.
        vm.startBroadcast(vm.envUint("DEPLOYER_PK"));

        logger = new Logger();
        morphoModule = new MorphoModule(logger);
        aggregatorsModule = new AggregatorsModule(logger);
        tokenActionsModule = new TokenActionsModule(logger);

        morpheous.setModule(Constants._AGGREGATORS_MODULE, address(aggregatorsModule));
        morpheous.setModule(Constants._TOKEN_ACTIONS_MODULE, address(tokenActionsModule));
        morpheous.setModule(Constants._MORPHO_MODULE, address(morphoModule));

        vm.stopBroadcast();
    }
}
