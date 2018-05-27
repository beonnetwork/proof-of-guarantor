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

  uint256 stakeThreshold = 1;
  mapping (address => bool) guarantors;
  mapping (address => uint256) stakes;
  mapping (bytes32 => Confirmation) confirmations;
  uint256 approvalThreshold;  

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

  constructor(uint256 _stakeThreshold) public {
    stakeThreshold = _stakeThreshold;
  }

  function isApproved(bytes32 txhash) public constant returns (bool) {
    return confirmations[txhash].approved;
  }

  function stake(uint256 amount) {
    require(amount > stakeThreshold);    
    stakes[msg.sender] = amount;
    emit Staked(msg.sender, amount);
  }

  function approve(bytes32 txhash) public onlyGuarantor {
    if ( confirmations[txhash].approved != true && confirmations[txhash].approvers_mask[msg.sender].confirmed != true ){
      confirmations[txhash].approvers.push(msg.sender);

      confirmations[txhash].approvers_mask[msg.sender].confirmed = true;
      
      // TODO[Phase 2]: Pick random miner
      confirmations[txhash].count += 1;
      if (confirmations[txhash].count >= approvalThreshold) {
        confirmations[txhash].approved = true;
        emit Approved(txhash);
      }
    }
  }


}
