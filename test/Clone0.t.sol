// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Clone0Factory} from "../src/Clone0Factory.sol";

contract SimpleContract {
    uint number = 69;
    address owner;

    error AlwaysRevert();

    function setOwner() public {
        owner = msg.sender;
    }

    function getOwner() public view returns(address){
        return owner;
    }

    function plusOne(uint a) public pure returns(uint){
        return a+1;
    }
    
    function returnArr(uint[] memory arr) public pure returns(uint[] memory){
        return arr;
    }

    function alwaysRevert() public pure {
        revert AlwaysRevert();
    }
}
contract Clone0FactoryTest is Test {
    Clone0Factory public factory; // clone0 factory
    SimpleContract public simple;  // implementation contract
    SimpleContract public clone0Simple; // clone contract
    address clone0; // proxy contract address
    address public alice = address(1);

    function setUp() public {
        simple = new SimpleContract();
        factory = new Clone0Factory();

        vm.startPrank(alice);
        clone0 = factory.clone0(address(simple));
        console2.logAddress(clone0);
        clone0Simple = SimpleContract(clone0);
        vm.stopPrank();
    }

    // test: call with no arguments and with fixed length return values
    function testNoArg() public {
        vm.prank(alice);
        clone0Simple.setOwner();
        address owner = clone0Simple.getOwner();
        assertEq(owner, alice);
    }

    // test: call with arguments
    function testWithArg() public {
        uint num = clone0Simple.plusOne(68);
        assertEq(num, 69);
    }

    // test: call with variable length return values
    function testVarReturn() public {
        uint[] memory arr1 = new uint[](2);
        arr1[0] = 1;
        arr1[1] = 2;
        uint[] memory arr2 = clone0Simple.returnArr(arr1);
        assertEq(arr1, arr2);
    }

    // test: call with revert
    function testRevert() public {
        vm.expectRevert();
        clone0Simple.alwaysRevert();
    }
}
