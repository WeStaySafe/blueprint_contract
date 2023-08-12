// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error NoValueSent();
error NotEnoughBalance();
error WithdrawLimitReached();
error PendingWithdraw();
error WithdrawNotUnlockedYet();

contract Blueprint {
    // Variables
    mapping(address => uint256) private balances;
    mapping(address => uint256) private withdawLimit;
    mapping(address => uint256) private blockUnlock;

    // Events
    event Deposit(address indexed _balanceOwner, uint256 _amount);
    event WithdrawRequest(address indexed _balanceOwner, uint256 _withdawLimit, uint256 _amount);
    event Withdraw(address indexed _balanceOwner, uint256 _amount);
    event Delay(address indexed _balanceOwner);
    event BlockAddress(address indexed _balanceOwner);
    event UnlockAddress(address indexed _balanceOwner);
    event CircuitBreak(uint256 _totalAmount);
    event ResetCircuitBreak(uint256 _totalAmount);

    // Mods

    // Structs, Arrays, Enums
    // Constructor

    // External functions
    function deposit() external payable {
        if (!(msg.value > 0)) revert NoValueSent();
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdrawRequest(uint256 _amount) external {
        if (balances[msg.sender] < _amount) revert NotEnoughBalance();
        if (withdawLimit[msg.sender] + _amount > balances[msg.sender]) revert WithdrawLimitReached();
        if (blockUnlock[msg.sender] > block.number) revert PendingWithdraw();
        withdawLimit[msg.sender] += _amount;
        // 21600 blocks = 12 hours delay to withdraw considering 2s per block
        blockUnlock[msg.sender] = block.number + 21600;
        emit WithdrawRequest(msg.sender, withdawLimit[msg.sender], _amount);
    }

    function withdraw() external {
        if (blockUnlock[msg.sender] > block.number) revert WithdrawNotUnlockedYet();
        uint256 amount = withdawLimit[msg.sender];
        withdawLimit[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    // Public functions

    // Internal functions

    // Private functions
}
