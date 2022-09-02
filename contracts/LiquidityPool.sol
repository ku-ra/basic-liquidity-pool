// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidityPool is ERC20 {
    address factory;
    address token1;
    address token2;

    uint112 private amount1;
    uint112 private amount2;
    uint32  private timestamp;

    uint public k;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    
    bool internal mutex;

    constructor(address _token1, address _token2) ERC20("LP Token", "LPX") {
        factory = msg.sender;
        token1 = _token1;
        token2 = _token2;
    }

    modifier reentrancyGuard() {
        require(!mutex, "No re-entrancy");
        mutex = true;
        _;
        mutex = false;
    }

    function _mint(address to) internal reentrancyGuard() {
        //Calculate difference between previous balance and new balance (amounts of tokens that got added)
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint balance2 = IERC20(token2).balanceOf(address(this));

        uint added1 = balance1 - amount1;
        uint added2 = balance2 - amount2;

        //Get total supply of lp tokens
        uint _totalSupply = totalSupply();

        //Calculate amount of tokens to mint
        uint liquidityShares;

        if (added1 == balance1 && added2 == balance2) {
            liquidityShares = sqrt((added1 * added2) - MINIMUM_LIQUIDITY);
            _mint(address(0x000000000000000000000000000000000000dEaD), MINIMUM_LIQUIDITY);
        }
        else {
            uint share1 = added1 * _totalSupply / amount1;
            uint share2 = added2 * _totalSupply / amount2;
            liquidityShares = share1 < share2 ? share1 : share2;
        }

        //Mint tokens
        _mint(to, liquidityShares);

        //Update balances
        _updateBalances(balance1, balance2);

        //Update k value
        _updateK();
    }

    function _updateK() internal {
        k = amount1 * amount2;
    }

    function _burn(address to) internal reentrancyGuard() {
        uint balance1 = ERC20(token1).balanceOf(address(this));
        uint balance2 = ERC20(token2).balanceOf(address(this));

        //Amount of tokens to burn
        uint _totalSupply = totalSupply();
        uint liquidityShares = balanceOf(address(this));

        //Calculate liquidity provider position
        uint _amount1 = balance1 * liquidityShares / _totalSupply;
        uint _amount2 = balance2 * liquidityShares / _totalSupply;
        
        require(_amount1 > 0 && _amount2 > 0, "Invalid amount of liquidity will be burnt");

        //Burn tokens
        _burn(address(this), liquidityShares);

        //Transfer tokens to lp
        IERC20(token1).transfer(to, _amount1);
        IERC20(token2).transfer(to, _amount2);

        //Updated balance of contract
        balance1 = ERC20(token1).balanceOf(address(this));
        balance2 = ERC20(token2).balanceOf(address(this)); 

        _updateBalances(balance1, balance2);

        _updateK();
    }

    function _updateBalances(uint _balance1, uint _balance2) internal {
        amount1 = uint112(_balance1);
        amount2 = uint112(_balance2);

        timestamp = uint32(block.timestamp % 2**32);
    }

    function depositLiquidity(uint _amount1, uint _amount2) external {
        //Check if amount ratio close to k

        if (amount1 == 0 && amount2 == 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), _amount1);
            IERC20(token2).transferFrom(msg.sender, address(this), _amount2);
        } 
        else {
            //Quote optimal amounts for other token
            uint optimal2 = exactConversion(_amount1, amount1, amount2);

            //Check if amounts provided are sufficient
            require(optimal2 <= _amount2, "Not enough tokens provided, please pay attention to the ratio of the pool");

            //Transfer tokens into contract
            IERC20(token1).transferFrom(msg.sender, address(this), _amount1);
            IERC20(token2).transferFrom(msg.sender, address(this), optimal2);
        }

        //Mint LP Tokens
        _mint(msg.sender);
    }

    function withdrawLiquidity(uint _liquidityShares) public {
        IERC20(address(this)).transferFrom(msg.sender, address(this), _liquidityShares);
        _burn(msg.sender);
    }

    function swap(uint _amount1, uint _amount2) public reentrancyGuard() {
        require(_amount1 > 0 || _amount2 > 0, "Invalid amounts specified");

        //Check which token is being requested for swap
        if (_amount1 > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), _amount1);
            uint output = exactConversion(_amount1, amount2, amount1);
            IERC20(token2).transfer(msg.sender, output);
        }

        if (_amount2 > 0) {
            IERC20(token2).transferFrom(msg.sender, address(this), _amount2);
            uint output = exactConversion(_amount2, amount2, amount1);
            IERC20(token1).transfer(msg.sender, output);
        }

        //Update reserve of tokens
        _updateBalances(amount1 - _amount1,amount2 - _amount2);

    }

    function exactConversion(uint _input, uint _reserveInput, uint _reserveOutput) internal pure returns(uint _output) {
        require(_input > 0, "");
        require(_reserveInput > 0 && _reserveOutput > 0, "");

        _output = _input * _reserveOutput / _reserveInput;
    }

    function exactFeeConversion(uint _input, uint _reserveInput, uint _reserveOutput) internal pure returns(uint _output) {
        require(_input > 0, "");
        require(_reserveInput > 0 && _reserveOutput > 0, "");

        uint fee = _input * (1000 - 3);
        _output = fee * _reserveOutput / fee * _reserveInput * 1000;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}