// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {console} from "forge-std/console.sol";
import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {DEPLOYER_SYSTEM_CONTRACT} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

contract ZksyncMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;
    using ECDSA for address;

    error ZksyncMinimalAccount__LessBalanceToPayFees();
    error ZksyncMinimalAccount__NotOwner();
    error ZksyncMinimalAccount__NotFromBoatLoader();
    error ZkMinimalAccount_ExecutionFailed();
    error ZkMinimalAccount_NotFromBootloaderOrOwner();
    error ZksyncMinimalAccount__FailedToPay();

    modifier requireFromBoatLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZksyncMinimalAccount__NotFromBoatLoader();
        }
        _;
    }

    modifier requireFromBootloaderOrOwner() {
        // Allow calls only from the official Bootloader address or the account's owner.
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount_NotFromBootloaderOrOwner();
        }
        _; // Proceed with function execution if the check passes
    }

    constructor() Ownable(msg.sender) {}
    //to validate transaction :
    // 1. first get the nonce verification by nonce holder
    // 2. check for fee to pay
    // 3. then get the signature verification

    function validateTransaction(
        bytes32, /*_txHash*/
        bytes32, /*_suggestedSignedHash*/
        Transaction calldata _transaction
    ) external payable requireFromBoatLoader returns (bytes4 magic) {
        
        magic = _validateTransaction(_transaction);
    }

    function executeTransaction(bytes32 /*_txHash*/, bytes32/* _suggestedSignedHash*/, Transaction calldata _transaction)
        external
        payable
        requireFromBootloaderOrOwner
    {
       _executeTransaction(_transaction);
        
    }
    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        _validateTransaction(_transaction);
        _executeTransaction(_transaction);
    }

    function payForTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction calldata _transaction)
        external
        payable
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZksyncMinimalAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable
    {}

    function _validateTransaction(Transaction calldata _transaction) internal returns (bytes4 magic) {
        // Check if the nonce is valid
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, _transaction.nonce)
        );
        console.log("Nonce incremented successfully");

        //fees to pay
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZksyncMinimalAccount__LessBalanceToPayFees();
        }

        console.log("gas fee calcualted successfully");

        //check the signature
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        console.log("Signature recovered successfully");
        console.log("Signer address: ", signer);
        //check the nonce
        if (signer != owner()) {
            magic = bytes4(0);
        } else {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        }
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
         address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;
        bool success;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            // This is a deployment transaction.
            // We need to call the deployer system contract using SystemContractsCaller.
            uint32 gas = Utils.safeCastToU32(gasleft()); // Get remaining gas, safely cast to uint32
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            // Handle normal external calls (to non-system contracts)
            assembly {
                // success := call(gas, to, value, in, insize, out, outsize)
                // gas(): current available gas for the call
                // to: the target address
                // value: the ETH value to send with the call
                // add(data, 0x20): pointer to the actual calldata (skipping the length prefix of bytes array)
                // mload(data): length of the calldata
                // 0, 0: pointer and length for return data (we are not capturing return data here)
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZkMinimalAccount_ExecutionFailed();
            }    
        } 
    }
}