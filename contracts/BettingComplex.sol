pragma solidity ^0.4.0;
import "./usingOraclize.sol";

contract Betting is usingOraclize {

    /*address public ac = 0x65AdFe318C8101e5F78123766c007ABD2D640431;
    address metamask = 0xc3Eb5dA9909CFc547985A93da4f65667f2a9701f;
    address myaccount = this;*/
    string public BTC_pre;
    string public BTC_post;
    string public ETH_pre;
    string public ETH_post;
    uint reward_amount;
    uint public voter_count=0;
    bytes32 BTC_ID;
    bytes32 ETH_ID;
    uint public countdown = 2;
    string public winner_horse;
    struct info{
        string horse;
        uint amount;
    }
    mapping (address => info) voter;
    mapping (uint => address) voterIndex;
    bool price_check = false;

    event newOraclizeQuery(string description);
    event newPriceTicker(string price);
    event Deposit(address _from, uint256 _value);
    event Withdraw(address _to, uint256 _value);

    function Betting() payable {
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        update(180);
    }

    function __callback(bytes32 myid, string result, bytes proof) {
        if (msg.sender != oraclize_cbAddress()) throw;
        if (myid == BTC_ID){
          if (price_check == false) {
            BTC_pre = result;
            price_check = true;
            newPriceTicker(BTC_pre);
            update(300);
          } else if (price_check == true){
            BTC_post = result;
            newPriceTicker(BTC_post);
            countdown = countdown - 1;
            if (countdown == 0){
              reward();
            }
          }
        } else if (myid == ETH_ID) {
          if (price_check == false) {
            ETH_pre = result;
            price_check = true;
            newPriceTicker(ETH_pre);
            update(300);
          } else if (price_check == true){
            ETH_post = result;
            newPriceTicker(ETH_post);
            countdown = countdown - 1;
            if (countdown == 0){
              reward();
            }
          }
        }
    }

    function placeBet(string horse) payable {
      voter[msg.sender].horse = horse;
      voter[msg.sender].amount = msg.value;
      voterIndex[voter_count] = msg.sender;
      voter_count = voter_count + 1;
      Deposit(msg.sender, msg.value);
    }

    function () payable {
      Deposit(msg.sender, msg.value);
    }

    function update(uint betting_duration) payable {
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            BTC_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/bitcoin/).0.price_usd");
            ETH_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/ethereum/).0.price_usd");
        }
    }

    function reward() payable {
      /*reward_amount = this.balance - 0.01 ether;*/
      uint winner_factor = 0;
      uint winner_count = 0;
      uint winner_reward;
      // calculate the percentage
      if ( (stringToUintNormalize(BTC_post) - stringToUintNormalize(BTC_pre)) > (stringToUintNormalize(ETH_post) - stringToUintNormalize(ETH_pre)) ) {
        winner_horse = "BTC";
      }
      else if ( (stringToUintNormalize(ETH_post) - stringToUintNormalize(ETH_pre)) > (stringToUintNormalize(BTC_post) - stringToUintNormalize(BTC_pre)) ) {
        winner_horse = "ETH";
      } else {
        throw;
      }

      for (uint i=0; i<voter_count; i++) {
        if (sha3(voter[voterIndex[voter_count]].horse) == sha3(winner_horse)) {
          winner_factor = winner_factor + voter[voterIndex[voter_count]].amount;
        }
      }
      for (i=0; i<voter_count; i++) {
        if (sha3(voter[voterIndex[voter_count]].horse) == sha3(winner_horse)) {
          winner_reward = (voter[voterIndex[voter_count]].amount / winner_factor )*this.balance;
          voterIndex[voter_count].transfer(winner_reward);
          Withdraw(voterIndex[voter_count], winner_reward);
        }
      }
    }

    function stringToUintNormalize(string s) constant returns (uint result) {
      bytes memory b = bytes(s);
      uint i;
      result = 0;
      for (i = 0; i < b.length; i++) {
        uint c = uint(b[i]);
        if (c >= 48 && c <= 57) {
          result = result * 10 + (c - 48);
        }
      }
      result/=100;
    }
    function getVoterAmount(address better) constant returns (uint) {
      return voter[msg.sender].amount;
    }

    function getVoterHorse(address better) constant returns (string) {
      return voter[msg.sender].horse;
    }
  }
