pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


contract UserBonus {

    using SafeMath for uint256;

    uint256 public constant BONUS_PERCENTS_PER_DAY = 1;

    struct UserBonusData {
        uint256 threadPaid;
        uint256 lastPaidTime;
        uint256 numberOfUsers;
        mapping(address => uint256) userPaid;
    }

    UserBonusData public bonus;

    event BonusPaid(uint256 users, uint256 amount);
    event UserAddedToBonus(address indexed user);

    modifier payRepBonusIfNeeded {
        payRepresentativeBonus();
        _;
    }

    modifier onlyRepBonusUser {
        require(userAddedToBonus(msg.sender));
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

    function userAddedToBonus(address user) public view returns(bool) {
        return bonus.userPaid[user] > 0;
    }

    function userBonus(address user) public view returns(uint256) {
        if (!userAddedToBonus(user)) {
            return 0;
        }
        return bonus.threadPaid.sub(bonus.userPaid[user]);
    }

    function retrieveBonus() public onlyRepBonusUser payRepBonusIfNeeded {
        uint256 amount = userBonus(msg.sender);
        require(amount > 0, "Nothing to retrieve");
        bonus.userPaid[msg.sender] = bonus.threadPaid;
        msg.sender.transfer(amount);
    }

    function _addUserToBonus(address user) internal {
        payRepresentativeBonus();

        require(bonus.userPaid[user] == 0);
        bonus.userPaid[user] = bonus.threadPaid;
        bonus.numberOfUsers = bonus.numberOfUsers.add(1);
        emit UserAddedToBonus(user);
    }
}
