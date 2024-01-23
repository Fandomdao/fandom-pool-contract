// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * Staking Token Wrapper
 */
pragma solidity ^0.8.20;

contract TokenWrapper {
    using SafeERC20 for IERC20;

    IERC20 public stakeToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        uint256 _before = stakeToken.balanceOf(address(this));
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 _after = stakeToken.balanceOf(address(this));
        uint256 _amount = _after - _before;

        _totalSupply = _totalSupply + _amount;
        _balances[msg.sender] = _balances[msg.sender] + _amount;
    }

    function instantUnstake(uint256 amount, uint256 penalty) internal {
        uint256 netAmount = amount - penalty;

        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;

        stakeToken.safeTransfer(msg.sender, netAmount);
    }

    function withdraw() public virtual {
        uint256 amount = _balances[msg.sender];

        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = 0;

        stakeToken.safeTransfer(msg.sender, amount);
    }

    function withdrawAccount(address account, uint256 amount) public virtual {
        _totalSupply = _totalSupply - amount;
        _balances[account] = _balances[account] - amount;
        stakeToken.safeTransfer(account, amount);
    }

    function withdrawExcessByAdmin() public virtual {
        uint256 contractBalance = stakeToken.balanceOf(address(this));
        require(
            contractBalance > _totalSupply,
            "POOL: No excess tokens to withdraw"
        );

        uint256 excessAmount = contractBalance - _totalSupply;
        stakeToken.safeTransfer(msg.sender, excessAmount);
    }
}

pragma solidity ^0.8.20;

contract DpPool is Initializable, TokenWrapper, OwnableUpgradeable {
    uint256 public constant UNSTAKE_DURATION = 72 hours; // 3 days

    uint256 public constant startTime = 0;

    bool private open;

    mapping(address => bool) private isStakeholder;
    mapping(address => uint256) private stakeholderIndex;
    address[] private stakeholders;

    mapping(address => uint256) public unstakeRequests;
    mapping(address => bool) public isUnstaking;

    event InstantUnstake(address indexed user, uint256 amount, uint256 penalty);
    event UnstakeRequested(address indexed user, uint256 timestamp);
    event UnstakeRequestCancelled(address indexed user);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event SetOpen(bool _open);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        IERC20 _startToken
    ) public initializer {
        __Ownable_init(initialOwner);

        stakeToken = _startToken;
        open = true;
    }

    function addStakeholder(address stakeholder) internal {
        if (!isStakeholder[stakeholder]) {
            isStakeholder[stakeholder] = true;
            stakeholderIndex[stakeholder] = stakeholders.length;
            stakeholders.push(stakeholder);
        }
    }

    function removeStakeholder(address stakeholder) internal {
        if (isStakeholder[stakeholder]) {
            isStakeholder[stakeholder] = false;

            uint256 index = stakeholderIndex[stakeholder];
            uint256 lastIndex = stakeholders.length - 1;
            address lastStakeholder = stakeholders[lastIndex];

            stakeholders[index] = lastStakeholder;
            stakeholderIndex[lastStakeholder] = index;

            stakeholders.pop();
            delete stakeholderIndex[stakeholder];
        }
    }

    function getStakeholders(
        uint256 startIndex,
        uint256 endIndex
    ) public view returns (address[] memory) {
        require(startIndex < endIndex, "POOL: Invalid index range");
        require(endIndex <= stakeholders.length, "POOL: Index out of bounds");

        address[] memory page = new address[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            page[i - startIndex] = stakeholders[i];
        }
        return page;
    }

    function getStakeholderDetails(
        uint256 startIndex,
        uint256 endIndex
    ) public view returns (address[] memory, uint256[] memory, bool[] memory) {
        require(startIndex < endIndex, "POOL: Invalid index range");
        require(endIndex <= stakeholders.length, "POOL: Index out of bounds");

        uint256 size = endIndex - startIndex;
        address[] memory addresses = new address[](size);
        uint256[] memory stakes = new uint256[](size);
        bool[] memory isUnstakingStatuses = new bool[](size);

        for (uint256 i = startIndex; i < endIndex; i++) {
            addresses[i - startIndex] = stakeholders[i];
            stakes[i - startIndex] = balanceOf(stakeholders[i]);
            isUnstakingStatuses[i - startIndex] = isUnstaking[stakeholders[i]];
        }

        return (addresses, stakes, isUnstakingStatuses);
    }

    function getStakeholder(uint256 index) public view returns (address) {
        require(index < stakeholders.length, "POOL: Index out of bounds");
        return stakeholders[index];
    }

    function getStakeholdersCount() public view returns (uint256) {
        return stakeholders.length;
    }

    function stake(uint256 amount) public override checkOpen checkStart {
        require(!isUnstaking[msg.sender], "POOL: In the process of unstaking");
        require(amount > 0, "POOL: Cannot stake 0");

        if (balanceOf(msg.sender) == 0) {
            addStakeholder(msg.sender);
        }

        super.stake(amount);

        emit Staked(msg.sender, amount);
    }

    function requestUnstake() public {
        require(balanceOf(msg.sender) > 0, "POOL: No stake to unstake");
        require(
            !isUnstaking[msg.sender],
            "POOL: Already in the process of unstaking"
        );

        unstakeRequests[msg.sender] = block.timestamp;
        isUnstaking[msg.sender] = true;
        emit UnstakeRequested(msg.sender, block.timestamp);
    }

    function cancelUnstakeRequest() public {
        require(
            isUnstaking[msg.sender],
            "POOL: Not in the process of unstaking"
        );

        isUnstaking[msg.sender] = false;
        unstakeRequests[msg.sender] = 0;
        emit UnstakeRequestCancelled(msg.sender);
    }

    function withdraw() public override {
        uint256 amount = balanceOf(msg.sender);

        require(amount > 0, "POOL: Cannot withdraw 0");
        require(
            isUnstaking[msg.sender],
            "POOL: Not in the process of unstaking"
        );
        require(
            block.timestamp >= unstakeRequests[msg.sender] + UNSTAKE_DURATION,
            "POOL: Unstake period not reached"
        );

        isUnstaking[msg.sender] = false;
        unstakeRequests[msg.sender] = 0;

        super.withdraw();
        removeStakeholder(msg.sender);

        emit Withdrawn(msg.sender, amount);
    }

    function instantUnstake() public {
        uint256 amount = balanceOf(msg.sender);

        require(amount > 0, "POOL: Cannot withdraw 0");
        require(
            !isUnstaking[msg.sender],
            "POOL: Already in the process of unstaking"
        );

        uint256 penalty = (amount * 10) / 100;

        super.instantUnstake(amount, penalty);
        removeStakeholder(msg.sender);

        emit InstantUnstake(msg.sender, amount, penalty);
    }

    function withdrawExcessByAdmin() public override onlyOwner {
        super.withdrawExcessByAdmin();
    }

    function withdrawAccount(
        address account,
        uint256 amount
    ) public override checkStart onlyOwner {
        require(amount > 0, "POOL: Cannot withdraw 0");

        super.withdrawAccount(account, amount);
        removeStakeholder(account);

        emit Withdrawn(account, amount);
    }

    modifier checkStart() {
        require(block.timestamp > startTime, "POOL: Not start");
        _;
    }

    modifier checkOpen() {
        require(open, "POOL: Pool is closed");
        _;
    }

    function isOpen() external view returns (bool) {
        return open;
    }

    function setOpen(bool _open) external onlyOwner {
        open = _open;
        emit SetOpen(_open);
    }
}
