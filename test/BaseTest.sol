// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {BaseTest} from "test/BaseTest.sol";
import {Logger} from "src/logger/Logger.sol";
import {Neo, TokenUtils} from "src/Neo.sol";
import {AggregatorsModule} from "src/modules/AggregatorsModule.sol";
import {TokenActionsModule} from "src/modules/TokenActionsModule.sol";
import {MorphoModule} from "src/modules/MorphoModule.sol";

import {ModuleA, ModuleB} from "test/utils/TestModules.sol";

import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Morphous, Constants} from "src/Morphous.sol";
import {LibString} from "solady/utils/LibString.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {FL} from "src/FL.sol";

abstract contract BaseTest is Utils {
    Neo neo;
    IDSProxy proxy;
    Logger logger;
    Morphous morpheous;
    FL fl;

    address internal constant _LOGGER_PLACEHOLDER = 0x1234567890123456789012345678901234567890;

    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant ZERO_EX_ROUTER = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
    address public constant INCH_ROUTER = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address internal constant _MAKER_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address internal constant _MORPHO_AAVE_LENS = 0x507fA343d0A90786d86C7cd885f5C49263A91FF4;
    address internal constant _MORPHO_COMPOUND_LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    function setUp() public virtual {
        logger = new Logger();

        // Deploy the contract with the correct constant address.
        morpheous = new Morphous();

        fl = new FL(address(morpheous));
        neo = new Neo(address(morpheous), address(fl));
        proxy = IDSProxy(IMakerRegistry(_MAKER_REGISTRY).build());

        // Modules
        AggregatorsModule aggregatorsModule = new AggregatorsModule(logger);
        TokenActionsModule tokenActionsModule = new TokenActionsModule(logger);
        MorphoModule morphoModule = new MorphoModule(logger);

        // Add modules
        morpheous.setModule(Constants._AGGREGATORS_MODULE, address(aggregatorsModule));
        morpheous.setModule(Constants._TOKEN_ACTIONS_MODULE, address(tokenActionsModule));
        morpheous.setModule(Constants._MORPHO_MODULE, address(morphoModule));
    }

    function testInitialSetup() public {
        assertEq(proxy.owner(), address(this));
    }
}
