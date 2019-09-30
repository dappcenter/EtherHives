pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


contract UserBonus {

    using SafeMath for uint256;

    uint256 public constant BONUS_PERCENTS_PER_DAY = 1;

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
        if (bonus.numberOfUsers > 0 && bonus.lastPaidTime.sub(block.timestamp) > 1 days) {
            uint256 reward = address(this).balance.mul(BONUS_PERCENTS_PER_DAY).div(100)
                .mul(block.timestamp.sub(bonus.lastPaidTime)).div(1 days);
            bonus.threadPaid = bonus.threadPaid.add(reward.div(bonus.numberOfUsers));
            bonus.lastPaidTime = block.timestamp;
            emit BonusPaid(bonus.numberOfUsers, reward);
        }
    }

    function userRegistered(address user) public view returns(bool) {
        return bonus.userRegistered[user];
    }

    function userBonus(address user) public view returns(uint256) {
        return bonus.userRegistered[user] ? bonus.threadPaid.sub(bonus.userPaid[user]) : 0;
    }

    function retrieveBonus() public payRepBonusIfNeeded {
        require(bonus.userRegistered[msg.sender]);

        uint256 amount = Math.min(address(this).balance, userBonus(msg.sender));
        bonus.userPaid[msg.sender] = bonus.userPaid[msg.sender].add(amount);
        msg.sender.transfer(amount);
    }

    function _addUserToBonus(address user) internal {
        require(!bonus.userRegistered[msg.sender]);
        payRepresentativeBonus();

        bonus.userRegistered[user] = true;
        bonus.userPaid[user] = bonus.threadPaid;
        bonus.numberOfUsers = bonus.numberOfUsers.add(1);
        emit UserAddedToBonus(user);
    }
}
