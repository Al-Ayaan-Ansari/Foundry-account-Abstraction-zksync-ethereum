// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {DeployMinimalAccount, HelperConfig} from "../script/DeployMinimalAccount.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "../script/sendPackedUserOp.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;
    PackedUserOperation[] public ops;

    function setUp() public {
        DeployMinimalAccount deployer = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deployer.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        address dest = address(usdc);
        uint256 value = 1e18;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), value);
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, 0, funcData);

        assertEq(usdc.balanceOf(address(minimalAccount)), value);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 1e18;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), value);

        // Act & Assert (Combined using expectRevert)
        vm.prank(makeAddr("randomUser"));

        vm.expectRevert(MinimalAccount.Error_InvalidEntryPointOrOwner.selector);

        minimalAccount.execute(dest, value, functionData);
    }

    function testSignatureOfSignedUserOperation() public view {
        //Arrange
        address dest = address(usdc);
        uint256 value = 1e18;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), value);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        //this is the data to be send from mempool node to entrypoint contract
        PackedUserOperation memory packedUserOperation = sendPackedUserOp.generateSignedPackedUserOps(
            executeCallData, helperConfig.getHelperConfig(), address(minimalAccount)
        );

        bytes32 userOpHash = IEntryPoint(helperConfig.getHelperConfig().entryPoint).getUserOpHash(packedUserOperation);

        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOperation.signature);

        //checking the signature is valid

        //Act
        assertEq(actualSigner, minimalAccount.owner());
    }

    function testValidationUserOps() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 1e18;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), value);

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        //this is the data to be send from mempool node to entrypoint contract
        PackedUserOperation memory packedUserOperation = sendPackedUserOp.generateSignedPackedUserOps(
            executeCallData, helperConfig.getHelperConfig(), address(minimalAccount)
        );

        bytes32 userOpHash = IEntryPoint(helperConfig.getHelperConfig().entryPoint).getUserOpHash(packedUserOperation);
        vm.prank(helperConfig.getHelperConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOperation, userOpHash, 1e18);

        assertEq(validationData, 0);
    }

    function testExecuteCommadByRandomUser() public {
        address dest = address(usdc);
        uint256 value = 1e18;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), value);

        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, 0, functionData);

        //this is the data to be send from mempool node to entrypoint contract
        PackedUserOperation memory packedUserOperation = sendPackedUserOp.generateSignedPackedUserOps(
            executeCallData, helperConfig.getHelperConfig(), address(minimalAccount)
        );

        console.log("working here..");

        ops.push(packedUserOperation);
        console.log("added in the array");

        vm.deal(address(minimalAccount), 1e18);
        console.log("added amount in minimalAccount");

        vm.prank(makeAddr("randomUser"));
        console.log(minimalAccount.owner());
        console.log(packedUserOperation.sender);

        IEntryPoint(helperConfig.getHelperConfig().entryPoint).handleOps(ops, payable(makeAddr("randomUser")));

        assertEq(usdc.balanceOf(address(minimalAccount)), value);
    }
}
