pragma solidity ^0.4.23;

import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

contract Guarantor is Ownable{
  using SafeMath for uint256;
      
  struct ConfirmData {
    bool confirmed;
  }

  struct Confirmation {
    address[] approvers;
    bool approved;
    bool confirmed;
    mapping (address => ConfirmData) approvers_mask;
    uint256 count;
  }

  struct VoteData {
    bool voted;
  }

  struct Challenge {
    uint256 voteUp;
    uint256 voteDown;
    bool start;
    bool end;
    uint blockNumber;
    mapping (address => VoteData) votes_mask;
  }

  uint256 stakeThreshold = 1;
  mapping (address => bool) guarantors;
  mapping (address => uint256) stakes;
  address[] stakers;
  mapping (bytes32 => Confirmation) confirmations;
  mapping (bytes32 => Challenge) challenges;
  uint256 approvalThreshold;  
  uint256 challengePeriod = 24*3600*12;

  function isGuarantor(address target) public view returns (bool) {
      return guarantors[target];
  }
  function assignGuarantor(address target) onlyOwner public {
      guarantors[target] = true;
  }
  function revokeGuarantor(address target) onlyOwner public {
      guarantors[target] = false;
  }
  modifier onlyGuarantor() {
    require(guarantors[msg.sender] == true);
    _;
  }
        
  mapping (uint256 => address) approvals;

  event Staked(address staker,  uint256 amount);
  event Approved(bytes32 txhash);
  event ChallengeStarted(bytes32 txhash);
  event VotedUp(address voter, bytes32 txhash);
  event VotedDown(address voter, bytes32 txhash);
  event ChallengeFinalized(bytes32 txhash);

  constructor(uint256 _stakeThreshold, uint256 _challengePeriod) public {
    stakeThreshold = _stakeThreshold;
    challengePeriod = _challengePeriod;
  }

  function isApproved(bytes32 txhash) public constant returns (bool) {
    return confirmations[txhash].approved;
  }

  function stake(uint256 amount) {
    require(amount > stakeThreshold);  
    stakers.push(msg.sender);  
    stakes[msg.sender] = amount;
    emit Staked(msg.sender, amount);
  }

  function challenge(bytes32 txhash) {
    require(challenges[txhash].start == false);
    require(challenges[txhash].end == false);

    challenges[txhash].start = true;
    challenges[txhash].blockNumber = block.number;

    emit ChallengeStarted(txhash);   
  }

  function voteUp(bytes32 txhash) {
    require(challenges[txhash].start == false);
    require(challenges[txhash].end == false);
    require(block.number < (challenges[txhash].blockNumber + challengePeriod));

    if ( challenges[txhash].start == true && challenges[txhash].end == true ){
      return;
    }

    if ( challenges[txhash].votes_mask[msg.sender].voted == true ){
      return;
    }

    challenges[txhash].voteUp = challenges[txhash].voteUp + 1;
    challenges[txhash].votes_mask[msg.sender].voted = true;
    emit VotedUp(msg.sender, txhash);
  }

  function voteDown(bytes32 txhash) {
    require(challenges[txhash].start == false);
    require(challenges[txhash].end == false);
    require(block.number < (challenges[txhash].blockNumber + challengePeriod));

    if ( challenges[txhash].start == true && challenges[txhash].end == true ){
      return;
    }

    if ( challenges[txhash].votes_mask[msg.sender].voted == true ){
      return;
    }

    challenges[txhash].voteDown = challenges[txhash].voteDown + 1;
    challenges[txhash].votes_mask[msg.sender].voted = true;
    emit VotedDown(msg.sender, txhash);
  }

  function finalizeChallenge(bytes32 txhash) {
    challenges[txhash].end = true;

    if(challenges[txhash].voteUp < challenges[txhash].voteDown) {
      // take the stake
      // stakes;
      for (uint i=0; i<stakers.length; i++) {
        owner.transfer(stakes[stakers[i]]);
        stakes[stakers[i]] = 0;      
      }
    }

    emit ChallengeFinalized(txhash);
  }

  function approve(bytes32 txhash) public onlyGuarantor {
    if ( confirmations[txhash].approved != true && confirmations[txhash].approvers_mask[msg.sender].confirmed != true ){
      confirmations[txhash].approvers.push(msg.sender);

      confirmations[txhash].approvers_mask[msg.sender].confirmed = true;
      
      confirmations[txhash].count += 1;
      if (confirmations[txhash].count >= approvalThreshold) {
        confirmations[txhash].approved = true;
        emit Approved(txhash);
      }
    }
  }


}
