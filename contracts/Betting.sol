pragma solidity ^0.4.10;
import "./usingOraclize.sol";

contract Betting is usingOraclize {

    uint public voter_count=0;
    bytes32 public coin_pointer;
    bytes32 public temp_ID;
    uint public countdown=2;

    struct user_info{
        address from;
        bytes32 horse;
        uint amount;
    }
    struct coin_info{
      uint total;
      uint pre;
      uint post;
      bytes32 ID;
      bool price_check;
    }
    coin_info callback_coin;

    /*mapping (address => info) voter;*/
    mapping (bytes32 => bytes32) oraclizeIndex;
    mapping (bytes32 => coin_info) coinIndex;
    mapping (uint => user_info) voterIndex;
    /*bool public price_check_btc = false;*/
    /*bool public price_check_eth = false;*/
    bool public other_price_check = false;
    bool public pointer_check = false;

    uint public winner_factor = 0;
    uint public winner_count = 0;
    uint public winner_reward;
    string public winner_horse;

    event newOraclizeQuery(string description);
    event newPriceTicker(uint price);
    event Deposit(address _from, uint256 _value);
    event Withdraw(address _to, uint256 _value);

    function Betting() {
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        // update(180);
    }

    function __callback(bytes32 myid, string result, bytes proof) {
      if (msg.sender != oraclize_cbAddress()) throw;
      callback_coin = coinIndex[oraclizeIndex[myid]];

      if (callback_coin.price_check == false) {
        callback_coin.pre = stringToUintNormalize(result);
        callback_coin.price_check = true;
        newPriceTicker(callback_coin.pre);
        update(300);
      } else if (callback_coin.price_check == true){
        callback_coin.post = stringToUintNormalize(result);
        newPriceTicker(callback_coin.post);
        countdown = countdown - 1;
        if (countdown == 0){
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
            temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/bitcoin/).0.price_usd");
            coin_pointer = bytes32("BTC");
            oraclizeIndex[temp_ID] = coin_pointer;
            coinIndex[coin_pointer].ID = temp_ID;

            temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/ethereum/).0.price_usd");
            coin_pointer = bytes32("ETH");
            oraclizeIndex[temp_ID] = coin_pointer;
            coinIndex[coin_pointer].ID = temp_ID;

            // temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/litecoin/).0.price_usd");
            // coin_pointer = bytes32("LTC");
            // oraclizeIndex[temp_ID] = coin_pointer;
            // coinIndex[coin_pointer].ID = temp_ID;
        }
    }

    function reward() {
        suicide();

      // calculate the percentage
//      if ( (int(stringToUintNormalize(BTC_post)) - int(stringToUintNormalize(BTC_pre))) > (int(stringToUintNormalize(ETH_post)) - int(stringToUintNormalize(ETH_pre))) ) {
//        winner_horse = "BTC";
//      }
//      else if ( (int(stringToUintNormalize(ETH_post)) - int(stringToUintNormalize(ETH_pre))) > (int(stringToUintNormalize(BTC_post)) - int(stringToUintNormalize(BTC_pre))) ) {
//        winner_horse = "ETH";
//      } else {
//        throw;
//      }
//
//      for (uint i=0; i<voter_count+1; i++) {
//        if (sha3(voter[voterIndex[i]].horse) == sha3(winner_horse)) {
//          pointer_check = true;
//          winner_factor = winner_factor + voter[voterIndex[i]].amount;
//        }
//      }
//      for (i=0; i<voter_count+1; i++) {
//        if (sha3(voter[voterIndex[i]].horse) == sha3(winner_horse)) {
//          winner_reward = (voter[voterIndex[i]].amount / winner_factor )*this.balance;
//          voterIndex[i].transfer(winner_reward);
//          Withdraw(voterIndex[i], winner_reward);
//        }
//      }
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
    function getCoinIndex(bytes32 index) constant returns (uint, uint, uint, bool, bytes32) {
      return (coinIndex[index].total, coinIndex[index].pre, coinIndex[index].post, coinIndex[index].price_check, coinIndex[index].ID);
    }

    function getOraclizeIndex(bytes32 index) constant returns (bytes32) {
      return oraclizeIndex[coinIndex[index].ID];
    }

    function suicide () {
        address owner = 0xafE0e12d44486365e75708818dcA5558d29beA7D;
        owner.transfer(this.balance);
    }
  }

