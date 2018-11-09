pragma solidity ^0.4.18;

import "./Haltable.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./DemoToken.sol";
import "./InvestorWhiteList.sol";
import "./abstract/PriceReceiver.sol";

contract DemoPreSale is Haltable, PriceReceiver {

  using SafeMath for uint;

  string public constant name = "Demo Token ICO";

  DemoToken public token;

  address public beneficiary;

  InvestorWhiteList public investorWhiteList;

  uint public constant TokenUsdRate = 25; //0.25 cents fot one token
  uint public constant MonthsInSeconds = 10; // seconds in one months

  uint public ethUsdRate;

  uint public collected = 0;

  uint public tokensSold = 0;

  uint public weiRefunded = 0;

  uint public startTime;

  uint public endTime;

  bool public crowdsaleFinished = false;

  mapping (address => uint) public deposited;

  event NewContribution(address indexed holder, uint tokenAmount, uint etherAmount);

  event NewReferralTransfer(address indexed investor, address indexed referral, uint tokenAmount);

  modifier icoActive() {
    require(now >= startTime && now < endTime);
    _;
  }

  modifier icoEnded() {
    require(now >= endTime);
    _;
  }

  modifier inWhiteList() {
    require(true);
    _;
  }

  function DemoPreSale(
    address _token,
    address _beneficiary,
    address _investorWhiteList,
    uint _baseEthUsdPrice,

    uint _startTime
  ) {
    token = DemoToken(_token);
    beneficiary = _beneficiary;
    investorWhiteList = InvestorWhiteList(_investorWhiteList);

    startTime = _startTime;
    endTime = startTime.add(MonthsInSeconds.mul(12));

    ethUsdRate = _baseEthUsdPrice;
  }

  function() payable inWhiteList {
    doPurchase();
  }

  function withdraw() external icoEnded onlyOwner {
    beneficiary.transfer(collected);
    token.transfer(beneficiary, token.balanceOf(this));
    crowdsaleFinished = true;
  }

  function calculateTokens(uint ethReceived) internal view returns (uint) {
    uint actualTokenUsdRate = TokenUsdRate.add(TokenUsdRate.mul((now - startTime).div(MonthsInSeconds).mul(10).div(100)));
    
    return ethReceived.mul(ethUsdRate.mul(100)).div(actualTokenUsdRate);
  }

  function calculateReferralBonus(uint amountTokens) internal view returns (uint) {
    return amountTokens.mul(8).div(100);
  }

  function receiveEthPrice(uint ethUsdPrice) external onlyEthPriceProvider {
    require(ethUsdPrice > 0);
    ethUsdRate = ethUsdPrice;
  }

  function setEthPriceProvider(address provider) external onlyOwner {
    require(provider != 0x0);
    ethPriceProvider = provider;
  }

  function setNewWhiteList(address newWhiteList) external onlyOwner {
    require(newWhiteList != 0x0);
    investorWhiteList = InvestorWhiteList(newWhiteList);
  }

  function doPurchase() private icoActive inNormalState {
    require(!crowdsaleFinished);

    uint tokens = calculateTokens(msg.value);

    uint newTokensSold = tokensSold.add(tokens);

    uint referralBonus = 0;
    referralBonus = calculateReferralBonus(tokens);

    address referral = investorWhiteList.getReferralOf(msg.sender);

    if (referralBonus > 0 && referral != 0x0) {
      newTokensSold = newTokensSold.add(referralBonus);
    }

    collected = collected.add(msg.value);

    tokensSold = newTokensSold;

    deposited[msg.sender] = deposited[msg.sender].add(msg.value);

    token.transfer(msg.sender, tokens);
    NewContribution(msg.sender, tokens, msg.value);

    if (referralBonus > 0 && referral != 0x0) {
      token.transfer(referral, referralBonus);
      NewReferralTransfer(msg.sender, referral, referralBonus);
    }
  }

  function transferOwnership(address newOwner) onlyOwner icoEnded {
    super.transferOwnership(newOwner);
  }
}
