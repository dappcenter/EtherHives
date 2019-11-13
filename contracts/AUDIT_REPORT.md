# EtherHives audit

## Minor

### Set compiler version to fixed

### Avoid using `now`, replace it with block.timestamp

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/UserBonus.sol#L31


https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/UserBonus.sol#L28-L29

`now` is easily overloadable and solc allows this.

## Medium

### `transfer` call before state interaction

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/UserBonus.sol#L47-L48

Move `transfer` to the end of the method call. Otherwise, future hardforks may bring vulnerabilities here.

## Major

### Forbid for the owner to register or use a separate counter to track admin withdrawals

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/EtherHives.sol#L61

### Level is unlockable only for honey

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/EtherHives.sol#L179

Implement level unlock for wax&honey.

### Wrong array bounds check for level upgrade

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/EtherHives.sol#L190-L191

Fix it with 

```
require(player.qualityLevel < (QUALITIES_COUNT-1));
```

### Wrong interval for representatives bonus

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/UserBonus.sol#L28

Use weekly bonuses. 

Also, it is better to use progressive percents.





## Critical

### Attacker can clean out the contract using 400 honey + 600 wax airdrop

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/EtherHives.sol#L201

Rewrite `earned&collect` logic to account airdrops only for wax.


### Representative bonuses are lesser then 1%

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/UserBonus.sol#L39-L49


1. At the beginning, we have 1 eth bonus and 1 user __A__ with 1 eth rights.
2. Something occurs and user __B__ is added with 0 eth rights
3. If each user tries to withdraw, __A__ could withdraw only 0.5 eth and __B__ could withdraw 0 eth.

So, only 0.5 eth from 1 eth of the available bonus is withdrawable.


### Any user can add himself into bonus receiver set without requirements and without increasing the divider (number of legal bonus receivers) and steal all money from the contract as the result

https://github.com/EtherHives/EtherHives/blob/f502013398bbfe6c65b272708021989c7416e287/contracts/UserBonus.sol#L48

1. call `retrieveBonus` from the user without rights to receive the bonus. User get nothing, but `bonus.userPaid` becomes nonzero.
2. after some time call `retrieveBonus` again. Now `userAddedToBonus` returns true and user can collect bonus, got by contract during the last interval.

The divider `bonus.numberOfUsers` does not grow, that mean that attacker can get all ethers from the contract.

