// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import {FL} from "src/FL.sol";
import {Logger} from "src/Logger.sol";
import {Neo, TokenUtils} from "src/Neo.sol";
import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {Morphous, Constants} from "src/Morphous.sol";
import {MorphoModule} from "src/modules/MorphoModule.sol";
import {AggregatorsModule} from "src/modules/AggregatorsModule.sol";
import {TokenActionsModule} from "src/modules/TokenActionsModule.sol";

abstract contract BaseTest is Utils {
    // Instance Variables

    FL fl;
    Neo neo;
    IDSProxy proxy;
    Logger logger;
    Morphous morphous;

    // Constants
    address internal constant _LOGGER_PLACEHOLDER = 0x1234567890123456789012345678901234567890;
    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant ZERO_EX_ROUTER = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
    address public constant INCH_ROUTER = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address public constant ODOS_ROUTER = 0x76f4eeD9fE41262669D0250b2A97db79712aD855;
    address internal constant _MAKER_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address internal constant _MORPHO_AAVE_LENS = 0x507fA343d0A90786d86C7cd885f5C49263A91FF4;
    address internal constant _MORPHO_COMPOUND_LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    ////////////////////////////////////////////////////////////////
    /// --- MODULES
    ///////////////////////////////////////////////////////////////

    bytes1 internal constant _AGGREGATORS_MODULE = 0x01;
    bytes1 internal constant _MORPHO_MODULE = 0x03;
    bytes1 internal constant _TOKEN_ACTIONS_MODULE = 0x02;

    // Functions
    function setUp() public virtual {
        logger = new Logger();
        morphous = new Morphous(address(this));
        fl = new FL(address(morphous));
        neo = new Neo(address(morphous), address(fl));
        proxy = IDSProxy(IMakerRegistry(_MAKER_REGISTRY).build());

        AggregatorsModule aggregatorsModule = new AggregatorsModule(logger);
        TokenActionsModule tokenActionsModule = new TokenActionsModule(logger);
        MorphoModule morphoModule = new MorphoModule(logger);

        morphous.setModule(_AGGREGATORS_MODULE, address(aggregatorsModule));
        morphous.setModule(_TOKEN_ACTIONS_MODULE, address(tokenActionsModule));
        morphous.setModule(_MORPHO_MODULE, address(morphoModule));
    }

    function testInitialSetup() public {
        assertEq(proxy.owner(), address(this));
    }
}
