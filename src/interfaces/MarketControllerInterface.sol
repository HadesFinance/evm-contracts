pragma solidity ^0.6.0;

interface MarketControllerInterface {
	/// @notice Emitted when an admin supports a market
	event MarketListed(address hToken);

	/// @notice Emitted when an account enters a market
	event MarketEntered(address hToken, address account);

	/// @notice Emitted when an account exits a market
	event MarketExited(address hToken, address account);

	/// @notice Emitted when close factor is changed by admin
	event NewCloseFactor(uint256 oldCloseFactorMantissa, uint256 newCloseFactorMantissa);

	/// @notice Emitted when a collateral factor is changed by admin
	event NewCollateralFactor(address hToken, uint256 oldCollateralFactorMantissa, uint256 newCollateralFactorMantissa);

	/// @notice Emitted when liquidation incentive is changed by admin
	event NewLiquidationIncentive(uint256 oldLiquidationIncentiveMantissa, uint256 newLiquidationIncentiveMantissa);

	/// @notice Emitted when maxAssets is changed by admin
	event NewMaxAssets(uint256 oldMaxAssets, uint256 newMaxAssets);

	/// @notice Emitted when pause guardian is changed
	event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);

	/// @notice Emitted when an action is paused globally
	event ActionPaused(string action, bool pauseState);

	/// @notice Emitted when an action is paused on a market
	event ActionPaused(address hToken, string action, bool pauseState);

	function initialize(
		address admin,
		address superior,
		address oracle
	) external;

	function enterMarkets(address[] calldata hTokens) external returns (uint256[] memory);

	function exitMarket(address hToken) external returns (uint256);

	/*** Policy Hooks ***/

	function mintAllowed(
		address hToken,
		address minter,
		uint256 mintAmount
	) external returns (uint256);

	function mintVerify(
		address hToken,
		address minter,
		uint256 mintAmount,
		uint256 mintTokens
	) external;

	function redeemAllowed(
		address hToken,
		address redeemer,
		uint256 redeemTokens
	) external returns (uint256);

	function redeemVerify(
		address hToken,
		address redeemer,
		uint256 redeemAmount,
		uint256 redeemTokens
	) external;

	function borrowAllowed(
		address hToken,
		address borrower,
		uint256 borrowAmount
	) external returns (uint256);

	function borrowVerify(
		address hToken,
		address borrower,
		uint256 borrowAmount
	) external;

	function repayBorrowAllowed(
		address hToken,
		address payer,
		address borrower,
		uint256 repayAmount
	) external returns (uint256);

	function repayBorrowVerify(
		address hToken,
		address payer,
		address borrower,
		uint256 repayAmount,
		uint256 borrowerIndex
	) external;

	function liquidateBorrowAllowed(
		address hTokenBorrowed,
		address hTokenCollateral,
		address liquidator,
		address borrower,
		uint256 repayAmount
	) external returns (uint256);

	function liquidateBorrowVerify(
		address hTokenBorrowed,
		address hTokenCollateral,
		address liquidator,
		address borrower,
		uint256 repayAmount,
		uint256 seizeTokens
	) external;

	function seizeAllowed(
		address hTokenCollateral,
		address hTokenBorrowed,
		address liquidator,
		address borrower,
		uint256 seizeTokens
	) external returns (uint256);

	function seizeVerify(
		address hTokenCollateral,
		address hTokenBorrowed,
		address liquidator,
		address borrower,
		uint256 seizeTokens
	) external;

	function transferAllowed(
		address hToken,
		address src,
		address dst,
		uint256 transferTokens
	) external returns (uint256);

	function transferVerify(
		address hToken,
		address src,
		address dst,
		uint256 transferTokens
	) external;

	/*** Liquidity/Liquidation Calculations ***/

	function liquidateCalculateSeizeTokens(
		address hTokenBorrowed,
		address hTokenCollateral,
		uint256 repayAmount
	) external view returns (uint256, uint256);

	/*** Admin interfaces ***/
	function _supportMarket(address hToken) external;
}
