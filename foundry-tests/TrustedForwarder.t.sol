// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/TrustedForwarder.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract TestApp is ERC2771Context {
    constructor(address trustedForwarder_) ERC2771Context(trustedForwarder_) {}

    function test0(uint256 x, string memory y) public payable returns (address, uint256, string memory, uint256) {
        return (_msgSender(), x + 1, string.concat(y, "test0"), msg.value);
    }

    function test1(uint256 x, string memory y) public payable returns (address, uint256, string memory, uint256) {
        return (_msgSender(), x * x, string.concat(y, "test1"), msg.value);
    }

    function test2(uint256 x, string memory y) public payable returns (address, uint256, string memory, uint256) {
        revert("test failed");
    }
}

contract TrustedForwarderTest is Test {
    TrustedForwarder public forwarder;
    TestApp public testApp;

    function setUp() public {
        forwarder = new TrustedForwarder();
        testApp = new TestApp(address(forwarder));
    }

    function testTrustedForwarder() external {
        uint256 totalValue = 6 ether;

        TrustedForwarder.Call3Value[] memory calls = new TrustedForwarder.Call3Value[](3);
        calls[0] = TrustedForwarder.Call3Value({
            target: address(testApp),
            allowFailure: false,
            value: 1 ether,
            callData: abi.encodeWithSignature("test0(uint256,string)", 123, "123")
        });
        calls[1] = TrustedForwarder.Call3Value({
            target: address(testApp),
            allowFailure: false,
            value: 2 ether,
            callData: abi.encodeWithSignature("test1(uint256,string)", 456, "456")
        });
        calls[2] = TrustedForwarder.Call3Value({
            target: address(testApp),
            allowFailure: true,
            value: 3 ether,
            callData: abi.encodeWithSignature("test2(uint256,string)", 789, "789")
        });

        // TrustedForwarderTest(user) => forwarder.aggregate3Value() => testApp.test()
        TrustedForwarder.Result[] memory res = forwarder.aggregate3Value{value: totalValue}(calls);
        (address msgSender, uint256 x, string memory y, uint256 val) = abi.decode(res[0].returnData, (address, uint256, string, uint256));
        assertEq(msgSender, address(this), "invalid erc2771 msg.sender");
        assertEq(x, 123 + 1, "invalid x");
        assertEq(y, "123test0", "invalid y");
        assertEq(val, 1 ether, "invalid val");

        (msgSender, x, y, val) = abi.decode(res[1].returnData, (address, uint256, string, uint256));
        assertEq(msgSender, address(this), "invalid erc2771 msg.sender");
        assertEq(x, 456 * 456, "invalid x");
        assertEq(y, "456test1", "invalid y");
        assertEq(val, 2 ether, "invalid val");

        assertEq(res[2].success, false, "invalid res[2].success");
    }
}
