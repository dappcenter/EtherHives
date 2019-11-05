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
        uint256 unlockedBee;
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
    uint256[BEES_COUNT] public BEES_PRICES = [0e18, 1500e18, 7500e18, 30000e18, 75000e18, 250000e18, 750000e18, 325000e18];
    uint256[BEES_COUNT] public BEES_LEVELS_PRICES = [0e18, 0e18, 11250e18, 45000e18, 112500e18, 375000e18, 1125000e18, 0];
    uint256[BEES_COUNT] public BEES_MONTHLY_PERCENTS = [0, 100, 102, 104, 106, 108, 111, 125];
    uint256[MEDALS_COUNT] public MEDALS_POINTS = [0e18, 50000e18, 190000e18, 510000e18, 1350000e18, 3225000e18, 5725000e18, 8850000e18, 12725000e18, 23500000e18];
    uint256[MEDALS_COUNT] public MEDALS_REWARDS = [0e18, 3500e18, 10500e18, 24000e18, 65000e18, 140000e18, 185000e18, 235000e18, 290000e18, 800000e18];
    uint256[QUALITIES_COUNT] public QUALITY_HONEY_PERCENT = [40, 42, 44, 46, 48, 50];
    uint256[QUALITIES_COUNT] public QUALITY_PRICE = [0e18, 31500e18, 95000e18, 235000e18, 475000e18, 785000e18];

    uint256 public constant COINS_PER_ETH = 500000;
    uint256 public constant MAX_BEES_PER_TARIFF = 32;
    uint256 public constant FIRST_BEE_AIRDROP_AMOUNT = 1000e18;
    uint256 public constant ADMIN_PERCENT = 10;
    uint256 public constant HONEY_DISCOUNT_PERCENT = 10;
    uint256 public constant SUPERBEE_PERCENT_UNLOCK = 25;
    uint256[] public REFERRAL_PERCENT_PER_LEVEL = [5, 3, 2];
    uint256[] public REFERRAL_POINT_PERCENT = [50, 25, 0];

    uint256 public maxBalance;
    uint256 public totalPlayers;
    uint256 public totalDeposited;
    uint256 public totalWithdrawed;
    uint256 public totalBeesBought;
    mapping(address => Player) public players;

    event Registered(address indexed user, address indexed referrer);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawed(address indexed user, uint256 amount);
    event ReferrerPaid(address indexed user, address indexed referrer, uint256 indexed level, uint256 amount);
    event MedalAwarded(address indexed user, uint256 indexed medal);
    event QualityUpdated(address indexed user, uint256 indexed quality);
    event RewardCollected(address indexed user, uint256 honeyReward, uint256 waxReward);
    event BeeUnlocked(address indexed user, uint256 bee);
    event BeesBought(address indexed user, uint256 bee, uint256 count);

    // For DEBUG
    function gift(uint256 amountHoney, uint256 amountWax) public {
        players[msg.sender].balanceHoney += amountHoney;
        players[msg.sender].balanceWax += amountWax;
    }

    function() external payable {
        if (msg.value == 0) {
            if (players[msg.sender].registered) {
                collect();
            }
        } else {
            deposit(address(0));
        }
    }

    function playerBees(address who) public view returns(uint256[BEES_COUNT] memory) {
        return players[who].bees;
    }

    function superBeeUnlocked() public view returns(bool) {
        uint256 adminWithdrawed = players[owner()].totalWithdrawed;
        return address(this).balance.add(adminWithdrawed) <= maxBalance.mul(100 - SUPERBEE_PERCENT_UNLOCK).div(100);
    }

    function referrals(address user) public view returns(address[] memory) {
        return players[user].referrals;
    }

    function referrerOf(address user, address ref) public view returns(address) {
        if (!players[user].registered && ref != user) {
            return ref;
        }
        return players[user].referrer;
    }

    function transfer(address account, uint256 amount) public returns(bool) {
        require(msg.sender == owner());
        _payWithWaxAndHoney(msg.sender, amount);
        players[account].balanceWax = players[account].balanceWax.add(amount);
        return true;
    }

    function deposit(address ref) public payable payRepBonusIfNeeded {
        Player storage player = players[msg.sender];
        address refAddress = referrerOf(msg.sender, ref);

        // Register player
        if (!player.registered) {
            require(msg.sender != owner(), "Owner can't play");
            player.registered = true;
            player.bees[0] = MAX_BEES_PER_TARIFF;
            player.unlockedBee = 1;
            player.lastTimeCollected = block.timestamp;
            totalBeesBought = totalBeesBought.add(MAX_BEES_PER_TARIFF);
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
        totalDeposited = totalDeposited.add(msg.value);
        player.points = player.points.add(wax);
        emit Deposited(msg.sender, msg.value);

        // collectMedals(msg.sender);

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
                // collectMedals(to);

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
        totalWithdrawed = totalWithdrawed.add(value);
        msg.sender.transfer(value);
        emit Withdrawed(msg.sender, value);
    }

    function collect() public payRepBonusIfNeeded {
        Player storage player = players[msg.sender];
        require(player.registered, "Not registered yet");

        if (!player.airdropCollected) {
            player.airdropCollected = true;
        }

        (uint256 balanceHoney, uint256 balanceWax) = this.instantBalance(msg.sender);
        emit RewardCollected(
            msg.sender,
            balanceHoney.sub(player.balanceHoney),
            balanceWax.sub(player.balanceWax)
        );

        player.balanceHoney = balanceHoney;
        player.balanceWax = balanceWax;
        player.lastTimeCollected = block.timestamp;
    }

    function instantBalance(address account)
        public
        view
        returns(
            uint256 balanceHoney,
            uint256 balanceWax
        )
    {
        Player storage player = players[account];
        if (!player.registered) {
            return (0, 0);
        }

        balanceHoney = player.balanceHoney;
        balanceWax = player.balanceWax;

        uint256 collected = earned(account);
        if (!player.airdropCollected) {
            collected = collected.sub(FIRST_BEE_AIRDROP_AMOUNT);
            balanceWax = balanceWax.add(FIRST_BEE_AIRDROP_AMOUNT);
        }

        uint256 honeyReward = collected.mul(QUALITY_HONEY_PERCENT[player.qualityLevel]).div(100);
        uint256 waxReward = collected.sub(honeyReward);

        balanceHoney = balanceHoney.add(honeyReward);
        balanceWax = balanceWax.add(waxReward);
    }

    function unlock(uint256 bee) public payable payRepBonusIfNeeded {
        Player storage player = players[msg.sender];

        if (msg.value > 0) {
            deposit(address(0));
        }

        require(bee < BEES_COUNT, "No more levels to unlock");
        require(player.bees[bee - 1] == MAX_BEES_PER_TARIFF, "Prev level must be filled");
        require(bee == player.unlockedBee + 1, "Trying to unlock wrong bee type");

        if (bee == 7) {
            require(player.medals >= 9);
        }
        if (bee == 8) {
            require(superBeeUnlocked());
        }
        _payWithWaxAndHoney(msg.sender, BEES_LEVELS_PRICES[bee]);
        player.unlockedBee = bee;
        player.bees[bee] = 1;
        emit BeeUnlocked(msg.sender, bee);
    }

    function buyBees(uint256 bee, uint256 count) public payable payRepBonusIfNeeded {
        Player storage player = players[msg.sender];

        if (msg.value > 0) {
            deposit(address(0));
        }

        collect();

        require(bee > 0, "Don't try to buy bees of type 0");
        require(bee <= player.unlockedBee, "This bee type not unlocked yet");

        require(player.bees[bee].add(count) <= MAX_BEES_PER_TARIFF);
        player.bees[bee] = player.bees[bee].add(count);
        totalBeesBought = totalBeesBought.add(count);
        _payWithWaxAndHoney(msg.sender, BEES_PRICES[bee].mul(count));

        emit BeesBought(msg.sender, bee, count);
    }

    function updateQualityLevel() public payRepBonusIfNeeded {
        Player storage player = players[msg.sender];

        require(player.qualityLevel < QUALITIES_COUNT - 1);
        _payWithHoneyOnly(msg.sender, QUALITY_PRICE[player.qualityLevel + 1]);
        player.qualityLevel++;
        emit QualityUpdated(msg.sender, player.qualityLevel);
    }

    function earned(address user) public view returns(uint256) {
        Player storage player = players[user];
        if (!player.registered) {
            return 0;
        }

        uint256 total = 0;
        for (uint i = 1; i < BEES_COUNT; i++) {
            total = total.add(
                player.bees[i].mul(BEES_PRICES[i]).mul(BEES_MONTHLY_PERCENTS[i]).div(100)
            );
        }

        return total
            .mul(block.timestamp.sub(player.lastTimeCollected))
            .div(30 days)
            .add(player.airdropCollected ? 0 : FIRST_BEE_AIRDROP_AMOUNT);
    }

    function collectMedals(address user) public payRepBonusIfNeeded {
        Player storage player = players[user];

        for (uint i = player.medals; i < MEDALS_COUNT; i++) {
            if (player.points >= MEDALS_POINTS[i]) {
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
        if (user != address(0) && !bonus.userRegistered[user]) {
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
