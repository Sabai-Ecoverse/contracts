// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract SabaiStaking is Ownable {

    IERC20 immutable private _token;

    uint256 private percentageOfEarnings;
    uint256 private penaltyPercentage;
    uint256 private minDeposit;
    uint256 private depositDuration;

    uint256 private planExpired;

    uint256 private totalActualDepositsAmount = 0;
    uint256 private totalDepositsAmount = 0;
    uint256 private totalActualDepositsCount = 0;
    uint256 private  totalDepositsCount = 0;

    struct Deposit {        
        uint256 startTS;
        uint256 endTS;        
        uint256 amount; 
        uint256 claimed;
        bool get;     
    }
    
    mapping(bytes32 => Deposit) deposits;
    mapping(uint256 => bytes32) depositsCounter;

    mapping(uint256 => address) users;
    mapping (address => bytes32[]) usersDeposits;
    mapping (bytes32 => address) depositsUsers;

    constructor(address _tokenAddress, uint256 _planExpired, uint256 _percentageOfEarnings, uint256 _penaltyPercentage, uint256 _minDeposit, uint256 _depositDuration) {
        require(_tokenAddress != address(0x0));

        _token = IERC20(_tokenAddress);

        planExpired = block.timestamp + _planExpired;
        
        percentageOfEarnings = _percentageOfEarnings;
        penaltyPercentage = _penaltyPercentage;
        minDeposit = _minDeposit;
        depositDuration = _depositDuration;
    }    

    function _checkUserDeposit(address _address, bytes32 _deposit_id) internal view returns(bool) {
        return depositsUsers[_deposit_id] == _address;
    }

    function getCurrentTime() private view returns(uint){
        return block.timestamp;
    }

    function getReward(bytes32 _depositId) public onlyOwner {
        require(deposits[_depositId].get == false, "You have already taken a deposit"); // You have already taken a deposit
        require(_checkUserDeposit(msg.sender, _depositId), "You are not the owner of the deposit"); // You are not the owner of the deposit

        // If the deposit is completed
        if (getCurrentTime() > deposits[_depositId].endTS) {
             deposits[_depositId].claimed = deposits[_depositId].amount + ((deposits[_depositId].amount / 100) * percentageOfEarnings);
        } else { // If the deposit is closed ahead of schedule (penalty)
            deposits[_depositId].claimed = deposits[_depositId].amount - ((deposits[_depositId].amount / 100) * penaltyPercentage);
        }

        require(_token.transfer(msg.sender, deposits[_depositId].claimed));
        totalActualDepositsAmount -= deposits[_depositId].claimed;

        deposits[_depositId].get = true;

        totalActualDepositsCount --;
    }

    function generateDepositId(address _address) private view returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(_address, totalDepositsCount)));
    }


    // Create a new deposit for an address
    function createDeposit(uint256 count) public payable {
        uint256 timestamp = getCurrentTime();

        require(timestamp < planExpired);
        require(count >= minDeposit);

        bytes32 deposit_id = generateDepositId(msg.sender);
        deposits[deposit_id] = Deposit(timestamp, timestamp+depositDuration, count, 0, false);
        depositsCounter[totalDepositsCount+1] = deposit_id;
        
        usersDeposits[msg.sender].push(deposit_id);

        require(_token.transferFrom(_msgSender(), address(this), count));

        depositsUsers[deposit_id] = msg.sender;

        totalDepositsAmount += count;
        totalDepositsCount ++;
        totalActualDepositsAmount += count;
        totalActualDepositsCount ++;
    }

    // Get deposit ids by address
    function getDepositIdsByAddress(address _address) public view returns (bytes32[] memory) { 
        return usersDeposits[_address];
    }

    // Get information about the deposit by deposit id
    function getDepositDataById(bytes32 _depositId) public view returns (Deposit memory) {
        return deposits[_depositId];
    }

    // Number of active deposits
    function getActualDepositsCount() public view returns(uint256) {
        return totalActualDepositsCount;
    }

    // Total number of deposits under the contract
    function getDepositsCount() public view returns(uint256) {
        return totalDepositsCount;
    }

    // Total value of all active deposits
    function getActualDipositsTotalAmount() public view returns(uint256) {
        return totalActualDepositsAmount;
    }

    // Total value of all deposits under the contract
    function getDipositsTotalAmount() public view returns(uint256) {
        return totalDepositsAmount;
    }

    // The amount of tokens on the contract without deposits
    function getContractBalance() public view returns(uint256) {
        return _token.balanceOf(address(this)) - totalActualDepositsAmount;
    }

    // How many tokens are required to provide rewards for all active deposits
    function getAmountToCloseactualDiposits() public view returns(uint256) {
        uint256 totalAmount = 0; 
        for(uint8 i = 0 ; i<totalDepositsCount; i++) {
            if (!deposits[depositsCounter[i]].get) {
                totalAmount+= ((deposits[depositsCounter[i]].amount / 100) * penaltyPercentage);
            }
        }

        return totalAmount;
    }

    // Get the rest of the tokens from the contract after the end of the offer
    function getRestOfDeposits() public onlyOwner {
        require(getCurrentTime() > planExpired); // Offer not completed yet
        
        uint256 lastDepositEndTimestamp = 0;
        for (uint i = 0; i < totalDepositsCount; i++) {
            if (deposits[depositsCounter[i]].endTS > lastDepositEndTimestamp) {
                lastDepositEndTimestamp = deposits[depositsCounter[i]].endTS;
            }
        }

        require(getCurrentTime() > lastDepositEndTimestamp + (60 * 60 * 24 * 30));

        require(_token.transfer(msg.sender, _token.balanceOf(address(this)) - totalActualDepositsAmount));
    }

    // Stop offers now (emergency)
    function stop() external onlyOwner {
        planExpired = getCurrentTime();
    }
}