pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


contract UserBonus {

    using SafeMath for uint256;

    uint256 public constant BONUS_PERCENTS_PER_DAY = 1;

    struct UserBonusData {
        uint256 totalPaid;
        uint256 lastPaidTime;
        uint256 numberOfUsers;
        mapping(address => uint256) userPaid;
    }

    UserBonusData public bonus;

    event BonusPaid(uint256 users, uint256 amount);
    event UserAddedToBonus(address indexed user);

    function payRepresentativeBonus() public {
        require(bonus.numberOfUsers > 0);

        uint256 reward = address(this).balance.mul(BONUS_PERCENTS_PER_DAY).div(100)
            .mul(now.sub(bonus.lastPaidTime)).div(1 days);
        bonus.totalPaid = bonus.totalPaid.add(reward);
        bonus.lastPaidTime = now;
        emit BonusPaid(bonus.numberOfUsers, reward);
    }

    function userAddedToBonus(address user) public view returns(bool) {
        return bonus.userPaid[user] > 0;
    }

    function userBonus(address user) public view returns(uint256) {
        if (!userAddedToBonus(user)) {
            return 0;
        }
        return bonus.totalPaid.sub(bonus.userPaid[user]).div(bonus.numberOfUsers);
    }

    function retrieveBonus() public {
        msg.sender.transfer(userBonus(msg.sender));
        bonus.userPaid[msg.sender] = bonus.totalPaid;
    }

    function _addUserToBonus(address user) internal {
        require(bonus.userPaid[user] == 0);
        bonus.userPaid[user] = bonus.totalPaid;
        bonus.numberOfUsers = bonus.numberOfUsers.add(1);
        emit UserAddedToBonus(user);
    }
}
