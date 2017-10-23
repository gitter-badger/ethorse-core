pragma solidity ^0.4.10;
import "./usingOraclize.sol";

contract Betting is usingOraclize {

    uint public voter_count=0;
    bytes32 public coin_pointer;
    bytes32 public temp_ID;
    uint public countdown=3;
    address public owner;
    int public BTC_delta;
    int public ETH_delta;
    int public LTC_delta;

    struct user_info{
        address from;
        bytes32 horse;
        uint amount;
    }
    struct coin_info{
      uint total;
      uint pre;
      uint post;
      uint count;
      bool price_check;
    }
    /*mapping (address => info) voter;*/
    mapping (bytes32 => bytes32) oraclizeIndex;
    mapping (bytes32 => coin_info) coinIndex;
    mapping (uint => user_info) voterIndex;

    uint public total_reward;
    bytes32 public winner_horse;
    uint public winner_reward;

    event newOraclizeQuery(string description);
    event newPriceTicker(uint price);
    event Deposit(address _from, uint256 _value);
    event Withdraw(address _to, uint256 _value);

    function Betting() {
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        owner = msg.sender;
        // update(180);
    }

    function __callback(bytes32 myid, string result, bytes proof) {
      if (msg.sender != oraclize_cbAddress()) throw;
      coin_pointer = oraclizeIndex[myid];

      if (coinIndex[coin_pointer].price_check != true) {
        coinIndex[coin_pointer].pre = stringToUintNormalize(result);
        coinIndex[coin_pointer].price_check = true;
        newPriceTicker(coinIndex[coin_pointer].pre);
      } else if (coinIndex[coin_pointer].price_check == true){
        coinIndex[coin_pointer].post = stringToUintNormalize(result);
        newPriceTicker(coinIndex[coin_pointer].post);
        countdown = countdown - 1;
        if (countdown == 0) {
            reward();
        }
      }
    }

    function placeBet(bytes32 horse) payable {
      voterIndex[voter_count].from = msg.sender;
      voterIndex[voter_count].amount = msg.value;
      voterIndex[voter_count].horse = horse;
      voter_count = voter_count + 1;
      coinIndex[horse].total = coinIndex[horse].total + msg.value;
      coinIndex[horse].count = coinIndex[horse].count + 1;

      Deposit(msg.sender, msg.value);
    }

    function () payable {
      Deposit(msg.sender, msg.value);
    }

    function update(uint betting_duration) payable {
        if (oraclize_getPrice("URL") > (this.balance)) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            temp_ID = oraclize_query(0, "URL", "json(http://api.coinmarketcap.com/v1/ticker/bitcoin/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("BTC");

            temp_ID = oraclize_query(0, "URL", "json(http://api.coinmarketcap.com/v1/ticker/ethereum/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("ETH");

            temp_ID = oraclize_query(0, "URL", "json(http://api.coinmarketcap.com/v1/ticker/litecoin/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("LTC");

            temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/bitcoin/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("BTC");

            temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/ethereum/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("ETH");

            temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/litecoin/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("LTC");
        }
    }

    function reward() {
      // calculate the percentage
      BTC_delta = int(coinIndex[bytes32("BTC")].post - coinIndex[bytes32("BTC")].pre)/int(coinIndex[bytes32("BTC")].pre);
      ETH_delta = int(coinIndex[bytes32("ETH")].post - coinIndex[bytes32("ETH")].pre)/int(coinIndex[bytes32("ETH")].pre);
      LTC_delta = int(coinIndex[bytes32("LTC")].post - coinIndex[bytes32("LTC")].pre)/int(coinIndex[bytes32("LTC")].pre);

      owner.transfer((this.balance*15)/100);

      if (BTC_delta > ETH_delta) {
          if (BTC_delta > LTC_delta) {
           winner_horse = bytes32("BTC");
          }
          else {
              winner_horse = bytes32("LTC");
          }
      } else {
          if (ETH_delta > LTC_delta) {
           winner_horse = bytes32("ETH");
          }
          else {
              winner_horse = bytes32("LTC");
          }
      }
     total_reward = this.balance;
     for (uint i=0; i<voter_count+1; i++) {
        if (voterIndex[i].horse == winner_horse) {
         winner_reward = (voterIndex[i].amount / coinIndex[winner_horse].total )*total_reward;
         voterIndex[i].from.transfer(winner_reward);
         Withdraw(voterIndex[i].from, winner_reward);
        }
     }
    }

    function stringToUintNormalize(string s) constant returns (uint) {
      uint p =2;
      bool happening=false;
      bytes memory b = bytes(s);
      uint i;
      uint result = 0;
      for (i = 0; i < b.length; i++) {
          if (happening == true) {
              p = p-1;
          }
          if (uint(b[i]) == 46){
              happening = true;
          }
          uint c = uint(b[i]);
          if (c >= 48 && c <= 57) {
            result = result * 10 + (c - 48);
          }
          if (happening==true && p == 0){
              return result;
          }
        }
      return result;
    }

    function getCoinIndex(bytes32 index) constant returns (uint, uint, uint, bool, uint) {
      return (coinIndex[index].total, coinIndex[index].pre, coinIndex[index].post, coinIndex[index].price_check, coinIndex[index].count);
    }

    function getUserCount(bytes32 index) constant returns (uint) {
        return coinIndex[index].count;
    }

    function getPoolValue(bytes32 index) constant returns (uint) {
        return coinIndex[index].total;
    }

    function suicide () {
        address owner = 0xafE0e12d44486365e75708818dcA5558d29beA7D;
        owner.transfer(this.balance);
    }
  }

