// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Clone0Factory} from "../src/Clone0Factory.sol";

// Test deployment of Clone0 contract with minimal creation code
contract Clone0FactoryTest is Test {
    Clone0Factory public factory; // clone0 factory
    address public implement = 0xBEbeBeBEbeBebeBeBEBEbebEBeBeBebeBeBebebe;
    address clone0; // proxy contract address
    function setUp() public {
        factory = new Clone0Factory();
        clone0 = factory.clone0(0xBEbeBeBEbeBebeBeBEBEbebEBeBeBebeBeBebebe);
    }

    function testRuntimeCode() public {
        bytes memory code = clone0.code;
        bytes memory codeExpected = hex"365f5f375f5f365f73bebebebebebebebebebebebebebebebebebebebe5af43d5f5f3e5f3d91602a57fd5bf3";
        console2.logBytes(code);
        assertEq(code, codeExpected);
    }
}
