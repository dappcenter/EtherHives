pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./UserBonus.sol";


contract BeeBee is Ownable, UserBonus {

    struct Player {
        bool registered;
        bool airdropCollected;
        address referrer;
        uint256 balanceHoney;
        uint256 balanceWax;
        uint256 points;
        uint256 medals;
        uint256 qualityLevel;
        uint256 lastTimeCollected;
        uint256[BEES_COUNT] bees;

        uint256 totalDeposited;
        uint256 totalWithdrawed;
        uint256 referralsTotalDeposited;
        uint256 subreferralsCount;
        address[] referrals;
    }

    uint256 public constant BEES_COUNT = 8;
    uint256 public constant MEDALS_COUNT = 10;
    uint256 public constant QUALITIES_COUNT = 6;
    uint256[BEES_COUNT] public BEES_PRICES = [0, 4000, 20000, 100000, 300000, 1000000, 2000000, 625000];
    uint256[BEES_COUNT] public BEES_LEVELS_PRICES = [0, 0, 30000, 150000, 450000, 1500000, 3000000, 0];
    uint256[BEES_COUNT] public BEES_MONTHLY_PERCENTS = [0, 100, 102, 104, 106, 108, 111, 125];
    uint256[MEDALS_COUNT] public MEDALS_POINTS = [0, 100000, 200000, 520000, 1040000, 2080000, 5200000, 10400000, 15600000, 26100000];
    uint256[MEDALS_COUNT] public MEDALS_REWARDS = [0, 6250, 12500, 31250, 62500, 125000, 312500, 625000, 937500, 1562500];
    uint256[QUALITIES_COUNT] public QUALITY_HONEY_PERCENT = [40, 42, 44, 46, 48, 50];
    uint256[QUALITIES_COUNT] public QUALITY_PRICE = [0, 50000, 150000, 375000, 750000, 1250000];

    uint256 public constant COINS_PER_ETH = 500000;
    uint256 public constant MAX_BEES_PER_TARIFF = 32;
    uint256 public constant FIRST_BEE_AIRDROP_AMOUNT = 1000;
    uint256 public constant ADMIN_PERCENT = 10;
    uint256 public constant HONEY_DISCOUNT_PERCENT = 10;
    uint256 public constant SUPERBEE_PERCENT_UNLOCK = 25;
    uint256[] public REFERRAL_PERCENT_PER_LEVEL = [5, 3, 2];
    uint256[] public REFERRAL_POINT_PERCENT = [50, 25, 0];

    uint256 public maxBalance;
    uint256 public totalPlayers;
    mapping(address => Player) public players;

    event Registered(address indexed user, address indexed referrer);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawed(address indexed user, uint256 amount);
    event ReferrerPaid(address indexed user, address indexed referrer, uint256 indexed level, uint256 amount);
    event MedalAwarded(address indexed user, uint256 indexed medal);
    event QualityUpdated(address indexed user, uint256 indexed quality);

    function superBeeUnlocked() public view returns(bool) {
        uint256 adminWithdrawed = players[owner()].totalWithdrawed;
        return address(this).balance.add(adminWithdrawed) <= maxBalance.mul(100 - SUPERBEE_PERCENT_UNLOCK).div(100);
    }

    function referrals(address user) public view returns(address[] memory) {
        return players[user].referrals;
    }

    function referrerOf(address user, address ref) public view returns(address) {
        if (players[user].referrer != address(0)) {
            return players[user].referrer;
        }
        if (players[user].totalDeposited == 0) {
            return ref;
        }
        return address(0);
    }

    function deposit(address ref) public payable {
        Player storage player = players[msg.sender];
        address refAddress = referrerOf(msg.sender, ref);

        // Register player
        if (!player.registered) {
            player.registered = true;
            player.bees[0] = MAX_BEES_PER_TARIFF;
            totalPlayers++;

            if (refAddress != address(0)) {
                player.referrer = refAddress;
                players[refAddress].referrals.push(msg.sender);

                if (players[refAddress].referrer != address(0)) {
                    players[players[refAddress].referrer].subreferralsCount++;
                }
            }
            emit Registered(msg.sender, refAddress);
        }

        // Update player record
        uint256 wax = msg.value.mul(COINS_PER_ETH);
        player.balanceWax = player.balanceWax.add(wax);
        player.totalDeposited = player.totalDeposited.add(msg.value);
        player.points = player.points.add(wax);
        emit Deposited(msg.sender, msg.value);

        collectMedals(msg.sender);

        // Pay admin fee fees
        players[owner()].balanceHoney = players[owner()].balanceHoney.add(
            msg.value.mul(ADMIN_PERCENT).div(100)
        );

        // Update referrer record if exist
        if (refAddress != address(0)) {
            Player storage referrer = players[refAddress];

            // Pay ref rewards
            address to = refAddress;
            for (uint i = 0; to != address(0) && i < REFERRAL_PERCENT_PER_LEVEL.length; i++) {
                uint256 reward = msg.value.mul(REFERRAL_PERCENT_PER_LEVEL[i]).div(100);
                players[to].balanceHoney = players[to].balanceHoney.add(reward);
                players[to].points = players[to].points.add(wax.mul(REFERRAL_POINT_PERCENT[i]).div(100));
                emit ReferrerPaid(msg.sender, to, i + 1, reward);
                collectMedals(to);

                to = players[to].referrer;
            }

            referrer.referralsTotalDeposited = referrer.referralsTotalDeposited.add(msg.value);
            _addToBonusIfNeeded(refAddress);
        }

        _addToBonusIfNeeded(msg.sender);

        uint256 adminWithdrawed = players[owner()].totalWithdrawed;
        maxBalance = Math.max(maxBalance, address(this).balance.add(adminWithdrawed));
    }

    function withdraw(uint256 amount) public {
        Player storage player = players[msg.sender];

        uint256 value = amount.div(COINS_PER_ETH);
        player.balanceHoney = player.balanceHoney.sub(amount);
        player.totalWithdrawed = player.totalWithdrawed.add(value);
        msg.sender.transfer(value);
        emit Withdrawed(msg.sender, value);
    }

    function collect() public {
        Player storage player = players[msg.sender];

        uint256 collected = earned(msg.sender);
        player.balanceHoney = collected.mul(QUALITY_HONEY_PERCENT[player.qualityLevel]).div(100);
        player.balanceWax = collected.mul(100 - QUALITY_HONEY_PERCENT[player.qualityLevel]).div(100);
        player.lastTimeCollected = now;
        if (!player.airdropCollected) {
            player.airdropCollected = true;
        }
    }

    function buyBees(uint256 bee, uint256 count) public payable {
        Player storage player = players[msg.sender];

        if (msg.value > 0) {
            deposit(address(0));
        }

        collect();

        require(bee < 2 || player.bees[bee - 1] == MAX_BEES_PER_TARIFF);
        if (player.bees[bee] == 0) {
            if (bee == 7) {
                require(player.medals >= 9);
            }
            if (bee == 8) {
                require(superBeeUnlocked());
            }
            _payWithWaxOnly(msg.sender, BEES_LEVELS_PRICES[bee]);
        }

        require(player.bees[bee].add(count) <= MAX_BEES_PER_TARIFF);
        player.bees[bee] = player.bees[bee].add(count);
        _payWithWaxAndHoney(msg.sender, BEES_PRICES[bee].mul(count));
    }

    function updateQualityLevel() public payable {
        Player storage player = players[msg.sender];

        require(player.qualityLevel < QUALITIES_COUNT);
        _payWithHoneyOnly(msg.sender, QUALITY_PRICE[player.qualityLevel + 1]);
        player.qualityLevel++;
        emit QualityUpdated(msg.sender, player.qualityLevel);
    }

    function earned(address user) public view returns(uint256) {
        Player storage player = players[user];

        uint256 total = 0;
        if (!player.airdropCollected) {
            total = total.add(FIRST_BEE_AIRDROP_AMOUNT);
        }

        for (uint i = 0; i < BEES_COUNT; i++) {
            total = total.add(
                player.bees[i].mul(BEES_PRICES[i]).mul(BEES_MONTHLY_PERCENTS[i]).div(100)
            );
        }

        return total
            .mul(now.sub(player.lastTimeCollected))
            .div(30 days);
    }

    function collectMedals(address user) public {
        Player storage player = players[user];

        for (uint i = player.medals; i < MEDALS_COUNT; i++) {
            if (player.points > MEDALS_POINTS[i]) {
                player.balanceWax = player.balanceWax.add(MEDALS_REWARDS[i]);
                player.medals = i + 1;
                emit MedalAwarded(user, i + 1);
            }
        }
    }

    function _payWithHoneyOnly(address user, uint256 amount) internal {
        Player storage player = players[user];
        player.balanceHoney = player.balanceHoney.sub(amount);
    }

    function _payWithWaxOnly(address user, uint256 amount) internal {
        Player storage player = players[user];
        player.balanceWax = player.balanceWax.sub(amount);
    }

    function _payWithWaxAndHoney(address user, uint256 amount) internal {
        Player storage player = players[user];

        uint256 wax = Math.min(amount, player.balanceWax);
        player.balanceWax = player.balanceWax.sub(wax);
        _payWithHoneyOnly(user, amount.sub(wax).mul(100 - HONEY_DISCOUNT_PERCENT).div(100));
    }

    function _addToBonusIfNeeded(address user) internal {
        if (user != address(0) && !userAddedToBonus(user)) {
            Player storage player = players[user];

            if (player.totalDeposited >= 5 ether &&
                player.referrals.length >= 10 &&
                player.referralsTotalDeposited >= 50 ether)
            {
                _addUserToBonus(user);
            }
        }
    }
}
