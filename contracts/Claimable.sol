pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";


contract Claimable is Ownable {

    address public pendingOwner;

    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner);
        _;
    }

    function renounceOwnership() public onlyOwner {
        revert();
    }

    function transferOwnership(address newOwner) public onlyOwner {
        pendingOwner = newOwner;
    }

    function claimOwnership() public onlyPendingOwner {
        _transferOwnership(pendingOwner);
        delete pendingOwner;
    }
}
