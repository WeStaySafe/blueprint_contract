// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error NoValueSent();
error CircuitBreakerOn();
error NotEnoughBalance();
error WithdrawLimitReached();
error PendingWithdraw();
error WithdrawNotUnlockedYet();
error CantDelayMoreThanADay();

contract Blueprint {
    // Variables
    mapping(address => uint256) private balances;
    mapping(address => uint256) private withdawLimit;
    mapping(address => uint256) private blockUnlock;
    mapping(address => address[]) private blockVotes;
    bool private circuitBreak = false;
    address[] private circuitBreakVotes;
    uint256 private totalParticipants = 0;

    // Events
    event Deposit(address indexed _balanceOwner, uint256 _amount);
    event WithdrawRequest(address indexed _balanceOwner, uint256 _withdawLimit, uint256 _amount);
    event Withdraw(address indexed _balanceOwner, uint256 _amount);
    event Delay(address indexed _balanceOwner);
    event BlockAddress(address indexed _balanceOwner);
    event UnlockAddress(address indexed _balanceOwner);
    event CircuitBreak(uint256 _totalVotes);
    event ResetCircuitBreak(uint256 _totalVotes);

    // External functions
    function deposit() external payable {
        if (!(msg.value > 0)) revert NoValueSent();
        if (circuitBreak) revert CircuitBreakerOn();
        if (balances[msg.sender] == 0) {
            totalParticipants += 1;
        }
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdrawRequest(uint256 _amount) external {
        if (balances[msg.sender] < _amount) revert NotEnoughBalance();
        if (withdawLimit[msg.sender] + _amount > balances[msg.sender]) revert WithdrawLimitReached();
        if (blockUnlock[msg.sender] > block.number) revert PendingWithdraw();
        if (circuitBreak) revert CircuitBreakerOn();
        withdawLimit[msg.sender] += _amount;
        // 21600 blocks = 12 hours delay to withdraw considering 2s per block
        blockUnlock[msg.sender] = block.number + 21600;
        emit WithdrawRequest(msg.sender, withdawLimit[msg.sender], _amount);
    }

    function withdraw() external {
        if (blockUnlock[msg.sender] > block.number) revert WithdrawNotUnlockedYet();
        if (circuitBreak) revert CircuitBreakerOn();
        uint256 amount = withdawLimit[msg.sender];
        withdawLimit[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        if (balances[msg.sender] == 0) {
            totalParticipants -= 1;
        }
        emit Withdraw(msg.sender, amount);
    }

    function delay(address _uncertainBalanceOwner) external {
        // Probably the delayer needs to pay some costs to do this action
        // If false alarm uncercertainBalanceOwner will get a little extra
        // If correct the delayer will get a reward from the uncercertainBalanceOwner
        // This will be decided by a blockWithdraw vote
        if (blockUnlock[_uncertainBalanceOwner] > block.number + 43200) revert CantDelayMoreThanADay();
        blockUnlock[_uncertainBalanceOwner] = block.number + 21600;
        emit Delay(_uncertainBalanceOwner);
    }

    function blockWithdraw(address _uncertainBalanceOwner) external {
        if (blockVoteExist(_uncertainBalanceOwner, msg.sender)) revert("Already voted");
        blockVotes[_uncertainBalanceOwner].push(msg.sender);
        // 200 years delay to withdraw considering 2s per block,
        // basically a block forever unless somebody becomes really old
        if (blockVotes[_uncertainBalanceOwner].length > totalParticipants / 3 && totalParticipants > 2) {
            blockUnlock[_uncertainBalanceOwner] = block.number + 3153600000;
            emit BlockAddress(_uncertainBalanceOwner);
        }
    }

    function unlock(address _uncertainBalanceOwner) external {
        for (uint256 i = 0; i < blockVotes[_uncertainBalanceOwner].length; i++) {
            if (blockVotes[_uncertainBalanceOwner][i] == msg.sender) {
                blockVotes[_uncertainBalanceOwner][i] =
                    blockVotes[_uncertainBalanceOwner][blockVotes[_uncertainBalanceOwner].length - 1];
                blockVotes[_uncertainBalanceOwner].pop();
                break;
            }
        }
        // Revert the block forever and schedule it for 12 hours unlock again
        if (blockVotes[_uncertainBalanceOwner].length < totalParticipants / 3 && totalParticipants > 2) {
            blockUnlock[_uncertainBalanceOwner] = block.number + 21600;
            emit UnlockAddress(_uncertainBalanceOwner);
        }
    }

    function circuitBreakerOn() external {
        if (circuitBreakVoteExist(msg.sender)) revert("Already voted");
        circuitBreakVotes.push(msg.sender);
        if (circuitBreakVotes.length > totalParticipants / 3 && totalParticipants > 2) {
            circuitBreak = true;
            emit CircuitBreak(circuitBreakVotes.length);
        }
    }

    function circuitBreakerOff() external {
        for (uint256 i = 0; i < circuitBreakVotes.length; i++) {
            if (circuitBreakVotes[i] == msg.sender) {
                circuitBreakVotes[i] = circuitBreakVotes[circuitBreakVotes.length - 1];
                circuitBreakVotes.pop();
                break;
            }
        }
        if (circuitBreakVotes.length < totalParticipants / 3 && totalParticipants > 2) {
            circuitBreak = false;
            emit ResetCircuitBreak(circuitBreakVotes.length);
        }
    }
    // Public functions

    function blockVoteExist(address _targetAddress, address _voteAddress) public view returns (bool) {
        for (uint256 i = 0; i < blockVotes[_targetAddress].length; i++) {
            if (blockVotes[_targetAddress][i] == _voteAddress) {
                return true;
            }
        }
        return false;
    }

    function circuitBreakVoteExist(address _voteAddress) public view returns (bool) {
        for (uint256 i = 0; i < circuitBreakVotes.length; i++) {
            if (circuitBreakVotes[i] == _voteAddress) {
                return true;
            }
        }
        return false;
    }
}
