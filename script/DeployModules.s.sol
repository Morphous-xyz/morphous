// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "forge-std/Script.sol";

import {Logger} from "src/Logger.sol";
import {Morphous, Constants} from "src/Morphous.sol";
import {MorphoModule} from "src/modules/MorphoModule.sol";
import {AggregatorsModule} from "src/modules/AggregatorsModule.sol";
import {TokenActionsModule} from "src/modules/TokenActionsModule.sol";

contract DeployModules is Script {
    Logger logger;
    MorphoModule morphoModule;
    AggregatorsModule aggregatorsModule;
    TokenActionsModule tokenActionsModule;
    Morphous morpheous = Morphous(payable(0xAeF22e74f7DcddEA150d779a4800e67319a960F3)); // Replace with the actual address of the deployed Morphous contract.

    ////////////////////////////////////////////////////////////////
    /// --- MODULES
    ///////////////////////////////////////////////////////////////

    bytes1 internal constant _AGGREGATORS_MODULE = 0x01;
    bytes1 internal constant _MORPHO_MODULE = 0x03;
    bytes1 internal constant _TOKEN_ACTIONS_MODULE = 0x02;

    function run() public {
        // Utilize the `DEPLOYER_PK` env variable to deploy contracts.
        vm.startBroadcast(vm.envUint("DEPLOYER_PK"));

        logger = new Logger();
        morphoModule = new MorphoModule(logger);
        aggregatorsModule = new AggregatorsModule(logger);
        tokenActionsModule = new TokenActionsModule(logger);

        morpheous.setModule(_MORPHO_MODULE, address(morphoModule));
        morpheous.setModule(_AGGREGATORS_MODULE, address(aggregatorsModule));
        morpheous.setModule(_TOKEN_ACTIONS_MODULE, address(tokenActionsModule));

        // Verifying all modules as been correctly setted
        if (
            morpheous.getModule(_AGGREGATORS_MODULE) != address(aggregatorsModule)
                || morpheous.getModule(_TOKEN_ACTIONS_MODULE) != address(tokenActionsModule)
                || morpheous.getModule(_MORPHO_MODULE) != address(morphoModule)
        ) {
            revert("Modules not setted correctly");
        }

        vm.stopBroadcast();
    }
}
