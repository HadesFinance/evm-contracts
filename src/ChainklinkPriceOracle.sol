pragma solidity ^0.6.0;

import "./interfaces/PriceOracleInterface.sol";
import "./interfaces/ChainlinkAggregatorV3Interface.sol";
import "./interfaces/HTokenInterface.sol";
import "./libraries/Strings.sol";
import "./libraries/SafeMath.sol";

contract ChainlinkPriceOracle is PriceOracleInterface {
	using SafeMath for uint256;

	mapping(string => ChainlinkAggregatorV3Interface) priceFeeds;

	function getUnderlyingPrice(address hToken) external override view returns (uint256) {
		string memory symbol = HTokenInterface(hToken).anchorSymbol();
		if (Strings.equals(symbol, "USD")) {
			return 1e18;
		}
		return queryChainlink(symbol);
	}

	function _setPriceFeedAddress(string memory symbol, address addr) public {
		priceFeeds[symbol] = ChainlinkAggregatorV3Interface(addr);
	}

	function queryChainlink(string memory symbol) internal view returns (uint256) {
		ChainlinkAggregatorV3Interface priceFeed = priceFeeds[symbol];
		if (address(priceFeed) == address(0)) {
			return 0;
		}
		(, int256 price, , , ) = priceFeed.latestRoundData();
		require(price > 0, "Unexpected price");
		return uint256(price).mul(1e10);
	}
}
