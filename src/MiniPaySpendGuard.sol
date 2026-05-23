// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MiniPaySpendGuard
/// @notice Non-custodial spend-policy proof for MiniPay-style payment flows on Celo.
/// @dev The contract never holds user funds. It only records per-user spend receipts.
contract MiniPaySpendGuard {
    error ZeroLimit();
    error ZeroAmount();
    error EmptyMerchant();
    error MonthlyLimitExceeded(uint256 attemptedTotalCents, uint256 monthlyLimitCents);
    error NativeFundsNotAccepted();

    struct MonthState {
        uint256 limitCents;
        uint256 spentCents;
        uint32 receiptCount;
    }

    mapping(address => uint256) public monthlyLimitCents;
    mapping(address => mapping(uint64 => uint256)) public userMonthSpendCents;
    mapping(address => mapping(uint64 => uint32)) public userMonthReceiptCount;

    event MonthlyLimitSet(address indexed user, uint256 limitCents);
    event SpendRecorded(
        address indexed user,
        bytes32 indexed merchantId,
        uint64 indexed monthKey,
        uint256 amountCents,
        uint256 monthTotalCents,
        string memo
    );

    function setMonthlyLimit(uint256 limitCents) external {
        if (limitCents == 0) revert ZeroLimit();

        monthlyLimitCents[msg.sender] = limitCents;
        emit MonthlyLimitSet(msg.sender, limitCents);
    }

    function recordSpend(bytes32 merchantId, uint256 amountCents, string calldata memo) external {
        if (merchantId == bytes32(0)) revert EmptyMerchant();
        if (amountCents == 0) revert ZeroAmount();

        uint256 limitCents = monthlyLimitCents[msg.sender];
        if (limitCents == 0) revert ZeroLimit();

        uint64 activeMonthKey = currentMonthKey();
        uint256 newTotal = userMonthSpendCents[msg.sender][activeMonthKey] + amountCents;
        if (newTotal > limitCents) revert MonthlyLimitExceeded(newTotal, limitCents);

        userMonthSpendCents[msg.sender][activeMonthKey] = newTotal;
        userMonthReceiptCount[msg.sender][activeMonthKey] += 1;

        emit SpendRecorded(msg.sender, merchantId, activeMonthKey, amountCents, newTotal, memo);
    }

    function getMonthState(address user, uint64 targetMonthKey)
        external
        view
        returns (MonthState memory state)
    {
        state.limitCents = monthlyLimitCents[user];
        state.spentCents = userMonthSpendCents[user][targetMonthKey];
        state.receiptCount = userMonthReceiptCount[user][targetMonthKey];
    }

    function currentMonthKey() public view returns (uint64) {
        return monthKey(block.timestamp);
    }

    function monthKey(uint256 timestamp) public pure returns (uint64) {
        return uint64(timestamp / 30 days);
    }

    receive() external payable {
        revert NativeFundsNotAccepted();
    }
}
