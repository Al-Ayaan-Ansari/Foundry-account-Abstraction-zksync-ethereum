// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test,console} from "forge-std/Test.sol";
import {ZksyncMinimalAccount} from "../src/zksync/ZksyncMinimalAccount.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC,MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {NONCE_HOLDER_SYSTEM_CONTRACT} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";

contract ZksyncMinimalAccountTest is Test {
    using MessageHashUtils for bytes32;
    ZksyncMinimalAccount zksyncMinimalAccount;
    ERC20Mock usdc;
    
    // bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba46cd47b2cff49341e7a3373594e7397d7483645a9385;


function setUp() public {
    zksyncMinimalAccount = new ZksyncMinimalAccount(); // Deploy the account contract
    // CRITICAL: Transfer ownership to the Anvil default account whose private key we use for signing.
    // This ensures that `signer == owner()` check passes inside the account's validation logic.
    zksyncMinimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
    usdc = new ERC20Mock(); // Deploy a mock ERC20 token for transaction data

    // CRITICAL: Deal ETH to the minimalAccount.
    // The ZkMinimalAccount's validateTransaction checks if the account has enough balance
    // to cover potential fees (derived from transaction gas parameters).
    vm.deal(address(zksyncMinimalAccount), AMOUNT); // AMOUNT can be 1 ether or any sufficient value
}

     function testZkOwnerCanExecuteCommands() public {
        // Arrange
        // address dest = address(usdc);
        // uint256 value = 0;
        // bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zksyncMinimalAccount), 1e18);

        Transaction memory transaction =
            _createUnsignedTransaction(zksyncMinimalAccount.owner(), 113, address(usdc), 0, abi.encodeWithSelector(ERC20Mock.mint.selector, address(zksyncMinimalAccount), 1e18));

        // Act
        vm.prank(zksyncMinimalAccount.owner());
        zksyncMinimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(usdc.balanceOf(address(zksyncMinimalAccount)), 1e18);
    }

        // Add assertions to check the state after execution

    // function testNonOwnerCannotExecuteCommands() public {
    //     address dest = address(this);
    //     uint256 value = 1e18;
    //     bytes memory funcData = abi.encodeWithSignature("receive()");

    //     vm.prank(address(0x123));
    //     vm.expectRevert("Not owner");
    //     zksyncMinimalAccount.execute(dest, value, funcData);
    // }

        function testZkValidateTransaction() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zksyncMinimalAccount), AMOUNT);

        // Create an unsigned zkSync Era transaction (type 113)
        // The _createUnsignedTransaction helper is assumed to be similar to previous lessons,
        // populating fields like nonce, from, to, gasLimit, gasPerPubdataByteLimit, etc.
        // For this lesson, `minimalAccount.owner()` is ANVIL_DEFAULT_ACCOUNT due to setUp.
        // The nonce should be the current expected nonce for the account.
        Transaction memory transaction =
            _createUnsignedTransaction(zksyncMinimalAccount.owner(), 113, dest, value, functionData);

        // Sign the transaction using a new helper
        transaction = _signTransaction(transaction);

        // Act
        // Simulate the call originating from the Bootloader
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        // The first two arguments (_txHash, _suggestedSignedHash) are passed as EMPTY_BYTES32
        // as they are not central to this basic signature validation test.
        bytes4 magic = zksyncMinimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC, "Validation did not return success magic");
    }
    
    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
    // 1. Encode the transaction hash for signing
    // MemoryTransactionHelper.encodeHash is specific to zkSync transaction structures
    bytes32 digest = MemoryTransactionHelper.encodeHash(transaction);
    // 2. Convert to Ethereum standard signed message hash format
    // This ensures compatibility with vm.sign, which expects an EIP-191 prefixed hash.
    // bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();
    // 3. Sign the digest using vm.sign and the known private key
    uint8 v;
    bytes32 r;
    bytes32 s;
    (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
    // 4. Create a mutable copy of the transaction to add the signature
    Transaction memory signedTransaction = transaction;

    // 5. Pack the signature components (r, s, v) into the signature field
    // The order r, s, v is a common convention.
    signedTransaction.signature = abi.encodePacked(r, s, v);
    console.log("Transaction signed with nonce: %s", signedTransaction.nonce);
    console.log("Transaction signature: ", string(signedTransaction.signature));
    return signedTransaction;
}

    function _createUnsignedTransaction(
    address from,
    uint8 transactionType,
    address to,
    uint256 value,
    bytes memory data
) internal view returns (Transaction memory) {
    // Fetch the nonce for the 'minimalAccount' (our smart contract account)
    // Note: vm.getNonce is a Foundry cheatcode. In a real zkSync environment,
    // you'd query the NonceHolder system contract.
    // uint256 nonce = vm.getNonce(address(zksyncMinimalAccount));
    uint256 nonce = INonceHolder(NONCE_HOLDER_SYSTEM_CONTRACT).getMinNonce(address(zksyncMinimalAccount));


    // Initialize an empty array for factory dependencies
    bytes32[] memory factoryDeps = new bytes32[](0);

    Transaction memory transaction;

   
        transaction.txType = transactionType;     // e.g., 113 for zkSync AA
        transaction.from= uint256(uint160(from));    // Cast 'from' address to uint256
        transaction.to= uint256(uint160(to));        // Cast 'to' address to uint256
        transaction.gasLimit= 16777216;        // Placeholder value (adjust as needed)
        transaction.gasPerPubdataByteLimit= 16777216; // Placeholder value
        transaction.maxFeePerGas= 16777216;           // Placeholder value
        transaction.maxPriorityFeePerGas= 16777216;   // Placeholder value
        transaction.paymaster= 0;                    // No paymaster for this example
        transaction.nonce=nonce;                    // Use the fetched nonce
        transaction.value= value;                     // Value to be transferred
        transaction.reserved= [uint256(0), uint256(0), uint256(0), uint256(0)]; // Default empty
        transaction.data= data;                       // Transaction calldata
        transaction.signature= hex"";                 // Empty signature for an unsigned transaction
        transaction.factoryDeps= factoryDeps;         // Empty factory dependencies
        transaction.paymasterInput= hex"";            // No paymaster input
        transaction.reservedDynamic= hex"";            // Empty reserved dynamic field
    console.log("Transaction created with nonce: %s", transaction.nonce);
    console.log("Transaction data: ", INonceHolder(NONCE_HOLDER_SYSTEM_CONTRACT).getMinNonce(address(zksyncMinimalAccount)));
    
    return transaction;

}
}