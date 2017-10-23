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
    bytes32 BTC;
    bytes32 ETH;
    bytes32 LTC;
    bool public betting_open=true;
    bool public race_start=false;

    struct user_info{
        address from;
        bytes32 horse;
        uint amount;
        bool rewarded;
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
    }

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }

    modifier lockBets {
        require(betting_open);
        _;
    }

    modifier startRace {
        require(!race_start);
        _;
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

    function placeBet(bytes32 horse) external payable {
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

    function update(uint betting_duration) payable startRace {
        if (oraclize_getPrice("URL") > (this.balance)) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            race_start = true;
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            // bets open price query
            temp_ID = oraclize_query(60, "URL", "json(http://api.coinmarketcap.com/v1/ticker/ethereum/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("ETH");

            temp_ID = oraclize_query(60, "URL", "json(http://api.coinmarketcap.com/v1/ticker/bitcoin/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("BTC");

            temp_ID = oraclize_query(60, "URL", "json(http://api.coinmarketcap.com/v1/ticker/litecoin/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("LTC");

            //bets closing price query
            // oraclize_setCustomGasPrice(400000);
            temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/bitcoin/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("BTC");

            temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/ethereum/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("ETH");

            temp_ID = oraclize_query(betting_duration, "URL", "json(http://api.coinmarketcap.com/v1/ticker/litecoin/).0.price_usd");
            oraclizeIndex[temp_ID] = bytes32("LTC");
        }
    }

    function reward() {
      // calculating the difference in price with a precision of 5 digits
      BTC=bytes32("BTC");
      ETH=bytes32("ETH");
      LTC=bytes32("LTC");
      BTC_delta = int(coinIndex[BTC].post - coinIndex[BTC].pre)/int(coinIndex[BTC].pre);
      ETH_delta = int(coinIndex[ETH].post - coinIndex[ETH].pre)/int(coinIndex[ETH].pre);
      LTC_delta = int(coinIndex[LTC].post - coinIndex[LTC].pre)/int(coinIndex[LTC].pre);

      // contract fee
      owner.transfer((this.balance*15)/100);

      if (BTC_delta > ETH_delta) {
          if (BTC_delta > LTC_delta) {
           winner_horse = BTC;
          }
          else {
              winner_horse = LTC;
          }
      } else {
          if (ETH_delta > LTC_delta) {
           winner_horse = ETH;
          }
          else {
              winner_horse = LTC;
          }
      }
     total_reward = this.balance;
     for (uint i=0; i<voter_count+1; i++) {
        if (voterIndex[i].horse == winner_horse) {
         winner_reward = (voterIndex[i].amount / coinIndex[winner_horse].total )*total_reward;
         if (!voterIndex[i].rewarded) {
            voterIndex[i].rewarded = true;
            voterIndex[i].from.transfer(winner_reward);
            Withdraw(voterIndex[i].from, winner_reward);
         }
        }
     }
    }

    function stringToUintNormalize(string s) constant returns (uint result) {
      uint p =2;
      bool precision=false;
      bytes memory b = bytes(s);
      uint i;
      result = 0;
      for (i = 0; i < b.length; i++) {
          if (precision == true) {p = p-1;}
          if (uint(b[i]) == 46){precision = true;}
          uint c = uint(b[i]);
          if (c >= 48 && c <= 57) {result = result * 10 + (c - 48);}
          if (precision==true && p == 0){return result;}
        }
      while (p!=0) {
        result = result*10;
        p=p-1;
      }
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

    function suicide () onlyOwner {
        owner.transfer(this.balance);
    }
  }