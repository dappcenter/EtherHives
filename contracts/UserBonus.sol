pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


contract UserBonus {

    using SafeMath for uint256;

    uint256 public constant BONUS_PERCENTS_PER_WEEK = 1;
    uint256 public constant BONUS_TIME = 1 weeks;

    struct UserBonusData {
        uint256 threadPaid;
        uint256 lastPaidTime;
        uint256 numberOfUsers;
        mapping(address => bool) userRegistered;
        mapping(address => uint256) userPaid;
    }

    UserBonusData public bonus;

    event BonusPaid(uint256 users, uint256 amount);
    event UserAddedToBonus(address indexed user);

    modifier payRepBonusIfNeeded {
        payRepresentativeBonus();
        _;
    }

    function payRepresentativeBonus() public {
        while (bonus.numberOfUsers > 0 && bonus.lastPaidTime.add(BONUS_TIME) <= block.timestamp) {
            uint256 reward = address(this).balance.mul(BONUS_PERCENTS_PER_WEEK).div(100);
            bonus.threadPaid = bonus.threadPaid.add(reward.div(bonus.numberOfUsers));
            bonus.lastPaidTime = bonus.lastPaidTime.add(BONUS_TIME);
            emit BonusPaid(bonus.numberOfUsers, reward);
        }
    }

    function userRegisteredForBonus(address user) public view returns(bool) {
        return bonus.userRegistered[user];
    }

    function userBonusPaid(address user) public view returns(uint256) {
        return bonus.userPaid[user];
    }

    function userBonusEarned(address user) public view returns(uint256) {
        return bonus.userRegistered[user] ? bonus.threadPaid.sub(bonus.userPaid[user]) : 0;
    }

    function retrieveBonus() public payRepBonusIfNeeded {
        require(bonus.userRegistered[msg.sender], "User not registered for bonus");

        uint256 amount = Math.min(address(this).balance, userBonusEarned(msg.sender));
        bonus.userPaid[msg.sender] = bonus.userPaid[msg.sender].add(amount);
        msg.sender.transfer(amount);
    }

    function _addUserToBonus(address user) internal payRepBonusIfNeeded {
        require(!bonus.userRegistered[msg.sender], "User already registered for bonus");

        if (bonus.numberOfUsers == 0) {
            bonus.lastPaidTime = block.timestamp;
        }

        bonus.userRegistered[user] = true;
        bonus.userPaid[user] = bonus.threadPaid;
        bonus.numberOfUsers = bonus.numberOfUsers.add(1);
        emit UserAddedToBonus(user);
    }
}
