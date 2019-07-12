pragma solidity ^0.5.4;

import "./Tokens/MogulDAI/MogulDAI.sol";
import "./Tokens/MogulToken/MogulToken.sol";
import "./Tokens/MovieToken/MovieToken.sol";
import "./Math/BondingMathematics.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Helpers/Whitelisting.sol";


contract MogulOrganisation is Whitelisting {

    using SafeMath for uint256;
    
    BondingMathematics public bondingMath;

    MogulDAI public mogulDAI;
    MogulToken public mogulToken;
    MovieToken public movieToken;

    address public mogulBank;

    uint256 public totalDAIInvestments = 0;
    
    uint256 constant public MOVIE_TO_MGL_RATE = 10; // 1 Mogul Token -> 10 Movie Tokens (Utility tokens)
    uint256 constant public DAI_RESERVE_REMAINDER = 5; // 20%
    uint256 constant public INITIAL_MGLTOKEN_SUPPLY = 1000000000000000000; // 1 Mogul Token

    event Invest(address investor, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event UnlockOrganisation(address unlocker, uint256 initialAmount, uint256 initialMglSupply);
    event DividendPayed(address payer, uint256 amount);
    
    constructor(address _bondingMath, address _mogulDAI, address _mogulToken, address _movieToken, address _mogulBank, address _whiteLister) Whitelisting(_whiteLister) public {
        
        require(_mogulDAI != address(0), "constructor:: Mogul DAI address is required");
        require(_movieToken != address(0), "constructor:: Movie Token address is required");
        require(_mogulBank != address(0), "constructor:: Mogul Bank address is required");
        require(_bondingMath != address(0), "constructor:: Bonding Math address is required");

        mogulToken = MogulToken(_mogulToken);
        mogulDAI = MogulDAI(_mogulDAI);
        movieToken = MovieToken(_movieToken);

        mogulBank = _mogulBank;
        bondingMath = BondingMathematics(_bondingMath);
        
    }
    
    function invest(uint256 _daiAmount, bytes memory signedData) public {
        require(totalDAIInvestments > 0, "invest:: Organisation is not unlocked for investments yet");
        require(mogulDAI.allowance(msg.sender, address(this)) >= _daiAmount, "invest:: Investor tries to invest with unapproved DAI amount");
        
        if (!whiteList[msg.sender]) {
            require(confirmedByWhiteLister(signedData));
            setWhitelisted(msg.sender, true);
        }

        uint256 mglTokensToMint = calcRelevantMGLForDAI(_daiAmount);

        uint256 reserveDAIAmount = _daiAmount.div(DAI_RESERVE_REMAINDER);
        mogulDAI.transferFrom(msg.sender, address(this), reserveDAIAmount);
        mogulDAI.transferFrom(msg.sender, mogulBank, _daiAmount.sub(reserveDAIAmount));

        mogulToken.mint(msg.sender, mglTokensToMint);
        movieToken.mint(msg.sender, mglTokensToMint.mul(MOVIE_TO_MGL_RATE));

        totalDAIInvestments = totalDAIInvestments.add(_daiAmount);

        emit Invest(msg.sender, _daiAmount);
    }
    
    function revokeInvestment(uint256 _amountMGL) public {
        require(mogulToken.allowance(msg.sender, address(this)) >= _amountMGL, "revokeInvestment:: Investor wants to withdraw MGL without allowance");
        
        uint256 daiToReturn = bondingMath.calcTokenSell(mogulToken.totalSupply(), mogulDAI.balanceOf(address(this)), _amountMGL);
        
        mogulDAI.transfer(msg.sender, daiToReturn);
        totalDAIInvestments = totalDAIInvestments.sub(daiToReturn);
        
        mogulToken.burnFrom(msg.sender, _amountMGL);

        emit Withdraw(msg.sender, daiToReturn);
    }
    
    function calcRelevantMGLForDAI(uint256 _daiAmount) public view returns(uint256) {
        uint256 tokensAfterPurchase = bondingMath.calcPurchase(mogulToken.totalSupply(), totalDAIInvestments, _daiAmount);
        return tokensAfterPurchase.sub(mogulToken.totalSupply());
    }
    
    function calcRelevantDAIForMGL(uint256 coTokenAmount) public view returns(uint256) {
        return bondingMath.calcTokenSell(mogulToken.totalSupply(), mogulDAI.balanceOf(address(this)), coTokenAmount);
    }
    
    function payDividends(uint256 dividendAmount)  public {
        require(totalDAIInvestments > 0, "payDividends:: Organisation is not unlocked for dividends payment yet");
        require(mogulDAI.allowance(msg.sender, address(this)) >= dividendAmount, "payDividends:: payer tries to pay with unapproved amount");
        
        uint256 reserveAmount = dividendAmount.div(DAI_RESERVE_REMAINDER);
        mogulDAI.transferFrom(msg.sender, address(this), reserveAmount);
        mogulDAI.transferFrom(msg.sender, mogulBank, dividendAmount.sub(reserveAmount));
        
        totalDAIInvestments = totalDAIInvestments.add(dividendAmount);
        
        emit DividendPayed(msg.sender, dividendAmount);
    }
    
    function unlockOrganisation(uint256 _unlockAmount, uint256 _initialMglSupply) public {
        require(totalDAIInvestments == 0, "unlockOrganisation:: Organization is already unlocked");
        require(mogulDAI.allowance(msg.sender, address(this)) >= _unlockAmount, "unlockOrganisation:: Unlocker tries to unlock with unapproved amount");

        mogulDAI.transferFrom(msg.sender, address(this), _unlockAmount.div(DAI_RESERVE_REMAINDER));
        mogulDAI.transferFrom(msg.sender, mogulBank, _unlockAmount.sub(_unlockAmount.div(DAI_RESERVE_REMAINDER)));
        
        totalDAIInvestments = _unlockAmount;
    
        mogulToken.mint(msg.sender, _initialMglSupply);
        
        emit UnlockOrganisation(msg.sender, _unlockAmount, _initialMglSupply);
    }
    
}