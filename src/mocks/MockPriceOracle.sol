pragma solidity ^0.6.0;

import "../interfaces/PriceOracleInterface.sol";
import "../interfaces/HTokenInterface.sol";
import "../libraries/Strings.sol";
import "../HErc20.sol";

contract MockPriceOracle is PriceOracleInterface {
	mapping(string => uint256) prices;

	function getUnderlyingPrice(address hToken) external override view returns (uint256) {
		string memory symbol = HTokenInterface(hToken).anchorSymbol();
		if (Strings.equals(symbol, "USD")) {
			return 1e18;
		} else {
			return prices[symbol];
		}
	}

	function setUnderlyingPrice(string memory symbol, uint256 priceMantissa) public {
		prices[symbol] = priceMantissa;
	}
}
