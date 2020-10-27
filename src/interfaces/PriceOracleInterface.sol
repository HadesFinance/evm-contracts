pragma solidity ^0.6.0;

interface PriceOracleInterface {
	/**
	 * @notice Get the underlying price of a hToken asset
	 * @param hToken The hToken to get the underlying price of
	 * @return The underlying asset price mantissa (scaled by 1e18).
	 *  Zero means the price is unavailable.
	 */
	function getUnderlyingPrice(address hToken) external view returns (uint256);
}
