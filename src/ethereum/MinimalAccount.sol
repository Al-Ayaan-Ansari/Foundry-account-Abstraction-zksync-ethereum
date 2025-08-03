// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {

    IEntryPoint entryPoint;

    error Error_InvalidEntryPoint();
    error Error_InvalidEntryPointOrOwner();
    error MinimalAccount_ExecutionFailed(bytes data);

    modifier requireFromEntryPoint() {
        if (msg.sender != address(entryPoint)) {
            revert Error_InvalidEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if(msg.sender != address(entryPoint) && msg.sender != owner()) {
            revert Error_InvalidEntryPointOrOwner();
        }
        _;
    }


    constructor(address _entryPoint) Ownable(msg.sender) {
        entryPoint = IEntryPoint(_entryPoint);
    }

    function execute(address dest, uint256 value, bytes calldata funcData) external requireFromEntryPointOrOwner{   
        (bool success, bytes memory data) = dest.call{value:value}(funcData);
        if(!success){
            revert MinimalAccount_ExecutionFailed(data);
        }
    }

    receive() external payable {}


    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payprefund(missingAccountFunds);
    }

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payprefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    /// getters ////

    function getEntryPoint() external view returns (address) {
        return address(entryPoint);
    }
}
