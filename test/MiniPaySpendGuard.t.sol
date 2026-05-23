// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/MiniPaySpendGuard.sol";

interface Vm {
    function deal(address who, uint256 newBalance) external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function prank(address msgSender) external;
    function warp(uint256 newTimestamp) external;
}

contract MiniPaySpendGuardTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MiniPaySpendGuard private guard;
    address private user = address(0xB0B);
    bytes32 private merchant = keccak256("merchant:local-market");

    function setUp() external {
        guard = new MiniPaySpendGuard();
        vm.warp(1_767_225_600); // 2026-01-01 UTC
    }

    function testUserCanSetLimitAndRecordSpend() external {
        vm.prank(user);
        guard.setMonthlyLimit(10_000);

        vm.prank(user);
        guard.recordSpend(merchant, 1_250, "coffee and data");

        uint64 key = guard.currentMonthKey();
        MiniPaySpendGuard.MonthState memory state = guard.getMonthState(user, key);

        require(state.limitCents == 10_000, "limit mismatch");
        require(state.spentCents == 1_250, "spent mismatch");
        require(state.receiptCount == 1, "receipt count mismatch");
    }

    function testMonthlyLimitBlocksOverspend() external {
        vm.prank(user);
        guard.setMonthlyLimit(2_000);

        vm.prank(user);
        guard.recordSpend(merchant, 1_500, "first payment");

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(MiniPaySpendGuard.MonthlyLimitExceeded.selector, 2_500, 2_000)
        );
        guard.recordSpend(merchant, 1_000, "blocked payment");
    }

    function testMonthBucketResetsAccounting() external {
        vm.prank(user);
        guard.setMonthlyLimit(2_000);

        vm.prank(user);
        guard.recordSpend(merchant, 1_500, "month one");

        vm.warp(1_767_225_600 + 31 days);

        vm.prank(user);
        guard.recordSpend(merchant, 1_000, "month two");

        MiniPaySpendGuard.MonthState memory state = guard.getMonthState(user, guard.currentMonthKey());
        require(state.spentCents == 1_000, "new month spent mismatch");
        require(state.receiptCount == 1, "new month count mismatch");
    }

    function testRejectsNativeFunds() external {
        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(MiniPaySpendGuard.NativeFundsNotAccepted.selector);
        payable(address(guard)).transfer(0.1 ether);
    }

    function testCannotRecordBeforeLimit() external {
        vm.prank(user);
        vm.expectRevert(MiniPaySpendGuard.ZeroLimit.selector);
        guard.recordSpend(merchant, 100, "missing limit");
    }
}
