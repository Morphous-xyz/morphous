// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {Neo} from "src/Neo.sol";
import {Morpheus} from "src/Morpheus.sol";

import {IDSProxy} from "src/interfaces/IDSProxy.sol";
import {BalancerFL} from "src/actions/flashloan/BalancerFL.sol";

interface MakerRegistry {
    function build() external returns (address proxy);
}

contract MorpheousTest is Test {
    Neo neo;
    Morpheus morpheous;
    BalancerFL balancerFL;

    IDSProxy proxy;

    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant _MAKER_REGISTRY = 0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4;

    function setUp() public {
        morpheous = new Morpheus();
        balancerFL = new BalancerFL();
        neo = new Neo(address(morpheous), address(balancerFL));
        proxy = IDSProxy(MakerRegistry(_MAKER_REGISTRY).build());
    }

    function testInitialSetup() public {
        assertEq(proxy.owner(), address(this));
    }

    function testFlashLoanBalancer() public {
        // Flashloan _userData.
        address _proxy = address(proxy);
        uint256 _deadline = block.timestamp + 15;
        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = abi.encodeWithSignature("hello()");
        bytes memory _flashLoanData = abi.encode(address(neo), _proxy, _deadline, _calldata);

        // Flashlaon functions parameters.
        address[] memory _tokens = new address[](1);
        _tokens[0] = _DAI;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 1e18;

        bytes memory _proxyData =
            abi.encodeWithSignature("executeFlashloan(address[],uint256[],bytes)", _tokens, _amounts, _flashLoanData);

        /// Morpheus function call.
        proxy.execute(address(neo), _proxyData);
    }
}
