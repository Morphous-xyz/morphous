// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Shifter} from "src/Shifter.sol";
import {Neo, TokenUtils} from "src/Neo.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Morpheus, Constants} from "src/Morpheus.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {FL} from "src/actions/flashloan/FL.sol";

contract StrategiesTest is Utils {
    FL fl;
    Neo neo;
    IDSProxy proxy;
    Shifter shifter;
    Morpheus morpheous;

    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant AUGUSTUS = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;
    address internal constant _MAKER_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;
    address internal constant _MORPHO_AAVE_LENS = 0x507fA343d0A90786d86C7cd885f5C49263A91FF4;
    address internal constant _MORPHO_COMPOUND_LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    function setUp() public {
        morpheous = new Morpheus();
        fl = new FL(address(morpheous));
        neo = new Neo(address(morpheous), address(fl));
        proxy = IDSProxy(IMakerRegistry(_MAKER_REGISTRY).build());

        shifter = new Shifter(address(morpheous), address(fl));
    }

    ////////////////////////////////////////////////////////////////
    /// --- SHIFTER
    ///////////////////////////////////////////////////////////////

    function testLoanShift() public {
        // Flashloan _userData.
        address _proxy = address(proxy);
        address _shifter = address(shifter);

        uint256 _amount = 1e18;
        uint256 _fee = _amount * 9 / 10000;

        deal(_DAI, _proxy, _fee);

        // Flashloan functions parameters.
        address[] memory _suppliedTokens = new address[](1);
        _suppliedTokens[0] = _DAI;
        uint256[] memory _suppliedAmounts = new uint256[](1);
        _suppliedAmounts[0] = _amount;

        bytes memory _proxyData = abi.encodeWithSignature(
            "shift(address[],uint256[],address[],address)",
            _suppliedTokens,
            _suppliedAmounts,
            _suppliedTokens,
            Constants._MORPHO_AAVE
        );

        proxy.execute(_shifter, _proxyData);
    }
}
