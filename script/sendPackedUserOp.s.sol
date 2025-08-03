// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";


contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;
    function run() public {

    }

    function generateSignedPackedUserOps(bytes memory callData, HelperConfig.NetConfig memory networkConfig,address smartContractAddress) public view returns (PackedUserOperation memory) {
        //1. Genereate unsigned message
         uint256 nonce = IEntryPoint(networkConfig.entryPoint).getNonce(smartContractAddress, 0);
        PackedUserOperation memory packedUserOperation = generateUnsignedUserOperation(callData,smartContractAddress, nonce);
        bytes32 userOpsHash = IEntryPoint(networkConfig.entryPoint).getUserOpHash(packedUserOperation);

        //digest of the message to be signed
        bytes32 digest = userOpsHash.toEthSignedMessageHash();

        //2. Signed the message
        uint256 LOCAL_ANVIL_ACCOUNT = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        uint8 v; bytes32 r; bytes32 s;
        if(block.chainid == 31337){
            console.log("entered the anvil chain..");
            (v,r,s) = vm.sign(LOCAL_ANVIL_ACCOUNT,digest);
        }
        else{
        (v,r,s)  = vm.sign(networkConfig.account,digest);
        }
        packedUserOperation.signature = abi.encodePacked(r,s,v); //this is the order of the whole signature

        
        return packedUserOperation;

        //3. Add the signature in the packedUserOps
    }
//     struct PackedUserOperation {
//     address sender;
//     uint256 nonce;
//     bytes initCode;
//     bytes callData;
//     bytes32 accountGasLimits;
//     uint256 preVerificationGas;
//     bytes32 gasFees;
//     bytes paymasterAndData;
//     bytes signature;
// }


    function generateUnsignedUserOperation(bytes memory callData, address smartContractAddress, uint256 nonce) internal pure returns(PackedUserOperation memory){
        uint128 verificationGasLimit = 150_000;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender:smartContractAddress,
            nonce:nonce,
            initCode:hex"",
            callData:callData,
            accountGasLimits:bytes32(uint256(verificationGasLimit) <<128 | callGasLimit),
            preVerificationGas:verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) <<128 | maxFeePerGas),
            paymasterAndData:hex"",
            signature:hex""
        });
    }
}
