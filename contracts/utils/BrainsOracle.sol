// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../lib/Babylonian.sol";
import "../lib/FixedPoint.sol";
import "../lib/UniswapV2OracleLibrary.sol";
import "../interfaces/IUniswapV2Pair.sol";

    // 000000000000000000

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract OracleBetter {
    using FixedPoint for *;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    // uniswap
    address public token0;         // brains -- erc20 ALWAYS 
    address public token1;          // local coin ALWAYS -- for the perfect result
    IUniswapV2Pair public pair;     // try getting this from pancekswap testnet -- ie the pair contract --

    IERC20 public paco;
    IERC20 public wftm;
    address public pairr;

    // oracle
    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    FixedPoint.uq112x112 public price0Average; //  structs
    FixedPoint.uq112x112 public price1Average;

    event Updated(uint256 price0CumulativeLast, uint256 price1CumulativeLast);

    constructor(
        IUniswapV2Pair _pair
    ) public {
        pair = _pair;
        token0 = pair.token0();
        token1 = pair.token1();
        price0CumulativeLast = pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, "Oracle: NO_RESERVES"); // ensure that there's liquidity in the pair
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    /** @dev Updates 1-day EMA price from Uniswap.  */
    function update() external {   // original -> function update() external checkEpoch ..
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        if (timeElapsed == 0) {
            // prevent divided by zero
            return;
        }

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));   // this shit i need to use to calculate rewards
        price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;

        emit Updated(price0Cumulative, price1Cumulative);
    }

     function twap(address _token, uint256 _amountIn) external view returns (uint144 _amountOut) {
         (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
         uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
         if (_token == token0) {
             _amountOut = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)).mul(_amountIn).decode144(); // Gives you how many coins u get for 1 bnb.
         } else if (_token == token1) {
             _amountOut = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)).mul(_amountIn).decode144(); // Gives you how many coins u get for 1 paco.
         }
     }
    
    function consult(address _token, uint256 _amountIn) external returns (uint144 amountOut) {
        if (_token == token0) {
            amountOut = price0Average.mul(_amountIn).decode144();
            factorial = uint(amountOut);
        } else {
            require(_token == token1, "Oracle: INVALID_TOKEN");
            amountOut = price1Average.mul(_amountIn).decode144();
            factorial = uint(amountOut);
        } //  Calling Paco as _token. Gives you how many usdt you would recieve by selling 1 paco. ---------IMPORTANT
          // Calling Bnb as _token. Gives you how many pacos you recieve for 1 usdt. -- "416".
    }

    uint public factorial; // only call with token0, 1e18

    function price(uint _bnb) public view returns(uint) {
        uint z = factorial / _bnb;
        return z;
    }

    // exporting function (mua)
    function calcFullPrice(uint _bnbPrice) external view returns(uint) {
        (, uint256 price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
         uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        uint144 _amountOut = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)).mul(1e18).decode144(); // Gives you how many coins u get for 1 paco.
        return uint(_amountOut) / _bnbPrice;
    }                   // this gets you the price of how many coins u get for 1 dollar. --- 1 dollar = 123000 brains 

    function calcFullPrice2(uint _bnbPrice) public view returns(uint) {
        (, uint256 price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
         uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
         
        uint144 _amountOut = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)).mul(1e18).decode144(); // Gives you how many coins u get for 1 paco.

        uint x = _bnbPrice * 1e18;
        return uint(_amountOut) / x;
        
    }

    function setPaco(address _add) public { // just call this
        paco = IERC20(token1);
        wftm = IERC20(token0);
        pairr = _add;
    }

    function cat() external view returns (uint144 amountOut) {
        uint256 tombBalance = wftm.balanceOf(pairr);
        uint256 wftmBalance = paco.balanceOf(pairr);
        return uint144(tombBalance.mul(wftmBalance)); 
        // will give you how many pacos are worth 1 usdt. ----IMPORTANT
    }

    function cat2() external view returns (uint144 amountOut) {
        uint256 tombBalance = paco.balanceOf(pairr);
        uint256 wftmBalance = wftm.balanceOf(pairr);
        return uint144(tombBalance.div(wftmBalance)); 
        // Currently gives you the amount of tokens required to reach 1 bnb. 124240 Brains.
    }


    // Ok you are supposed to call twap(_bnb, 1e18) -> this will return u how many erc20 coins give you 1 bnb. 
    // With brains (pair: 0xA23c7e1DEc8164B473F829D91a444971E81230Ec). You get 60 million for 1 bnb. 

    // 

}