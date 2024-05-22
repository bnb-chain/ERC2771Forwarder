// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

contract TrustedForwarder is ERC2771Forwarder {

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    constructor() ERC2771Forwarder("TrustedForwarder") {}

    /// @dev add erc2771 support based on Multicall3(https://github.com/mds1/multicall/blob/a1fa0644fa412cd3237ef7081458ecb2ffad7dbe/src/Multicall3.sol#L129)
    /// @notice Aggregate calls with a msg value
    /// @notice Reverts if msg.value is less than the sum of the call values
    /// @param calls An array of Call3Value structs
    /// @return returnData An array of Result structs
    function aggregate3Value(Call3Value[] calldata calls) public payable returns (Result[] memory returnData) {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3Value calldata calli;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            uint256 val = calli.value;
            // Humanity will be a Type V Kardashev Civilization before this overflows - andreas
            // ~ 10^25 Wei in existence << ~ 10^76 size uint fits in a uint256
            unchecked {
                valAccumulator += val;
            }

            /**
             * @dev The EIP-2771 defines a contract-level protocol for Recipient contracts to accept
             * meta-transactions through trusted Forwarder contracts. No protocol changes are made.
             * Recipient contracts are sent the effective msg.sender (referred to as _msgSender())
             * and msg.data (referred to as _msgData()) by appending additional calldata.
             * EIP-2771 doc: https://eips.ethereum.org/EIPS/eip-2771
             */
            (result.success, result.returnData) = calli.target.call{value: val}(
                abi.encodePacked(calli.callData, msg.sender)
            );

            if (!calli.allowFailure && !result.success) {
                bytes memory revertData = result.returnData;
                uint256 len = revertData.length;
                assembly {
                    revert(add(revertData, 0x20), len)
                }
            }

            unchecked {
                ++i;
            }
        }
        // Finally, make sure the msg.value = SUM(call[0...i].value)
        require(msg.value == valAccumulator, "value mismatch");
    }
}
