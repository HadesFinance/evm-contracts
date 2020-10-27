pragma solidity ^0.6.0;

import "./libraries/Strings.sol";
import "./HToken.sol";
import "./DOL.sol";

/**
 * @title Hades' HErc20 Contract
 * @notice HTokens which wrap an EIP-20 underlying
 * @author Hades
 */
contract HErc20 is HToken, HErc20Interface {
	address public underlying;

	/**
	 * @notice Initialize the new money market
	 * @param _underlying The address of the underlying asset
	 * @param _controller The address of the MarketController
	 * @param _interestRateStrategy The address of the interest rate model
	 * @param _distributor The address of the distributor contract
	 * @param _name ERC-20 name of this token
	 * @param _symbol ERC-20 symbol of this token
	 * @param _anchorSymbol The anchor asset
	 */
	function initialize(
		address payable _admin,
		address _underlying,
		MarketControllerInterface _controller,
		InterestRateStrategyInterface _interestRateStrategy,
		DistributorInterface _distributor,
		string calldata _name,
		string calldata _symbol,
		string calldata _anchorSymbol
	) external {
		// HToken initialize does the bulk of the work
		super.initialize(_admin, _controller, _interestRateStrategy, _distributor, _name, _symbol, _anchorSymbol);

		// Set underlying and sanity check it
		underlying = _underlying;
		EIP20Interface(underlying).totalSupply();
	}

	/*** User Interface ***/

	/**
	 * @notice Sender supplies assets into the market and receives hTokens in exchange
	 * @dev Accrues interest whether or not the operation succeeds, unless reverted
	 * @param mintAmount The amount of the underlying asset to supply
	 * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
	 */
	function mint(uint256 mintAmount) external override returns (uint256) {
		(uint256 err, ) = mintInternal(mintAmount);
		return err;
	}

	/**
	 * @notice Sender redeems hTokens in exchange for the underlying asset
	 * @dev Accrues interest whether or not the operation succeeds, unless reverted
	 * @param redeemTokens The number of hTokens to redeem into underlying
	 * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
	 */
	function redeem(uint256 redeemTokens) external override returns (uint256) {
		return redeemInternal(redeemTokens);
	}

	/**
	 * @notice Sender redeems hTokens in exchange for a specified amount of underlying asset
	 * @dev Accrues interest whether or not the operation succeeds, unless reverted
	 * @param redeemAmount The amount of underlying to redeem
	 * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
	 */
	function redeemUnderlying(uint256 redeemAmount) external override returns (uint256) {
		return redeemUnderlyingInternal(redeemAmount);
	}

	/**
	 * @notice Sender borrows assets from the protocol to their own address
	 * @param borrowAmount The amount of the underlying asset to borrow
	 * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
	 */
	function borrow(uint256 borrowAmount) external override returns (uint256) {
		return borrowInternal(borrowAmount);
	}

	/**
	 * @notice Sender repays their own borrow
	 * @param repayAmount The amount to repay
	 * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
	 */
	function repayBorrow(uint256 repayAmount) external override returns (uint256) {
		(uint256 err, ) = repayBorrowInternal(repayAmount);
		return err;
	}

	/**
	 * @notice Sender repays a borrow belonging to borrower
	 * @param borrower the account with the debt being payed off
	 * @param repayAmount The amount to repay
	 * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
	 */
	function repayBorrowBehalf(address borrower, uint256 repayAmount) external override returns (uint256) {
		(uint256 err, ) = repayBorrowBehalfInternal(borrower, repayAmount);
		return err;
	}

	/**
	 * @notice The sender liquidates the borrowers collateral.
	 *  The collateral seized is transferred to the liquidator.
	 * @param borrower The borrower of this hToken to be liquidated
	 * @param repayAmount The amount of the underlying borrowed asset to repay
	 * @param hTokenCollateral The market in which to seize collateral from the borrower
	 * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
	 */
	function liquidateBorrow(
		address borrower,
		uint256 repayAmount,
		HTokenInterface hTokenCollateral
	) external override returns (uint256) {
		(uint256 err, ) = liquidateBorrowInternal(borrower, repayAmount, hTokenCollateral);
		return err;
	}

	/*** Safe Token ***/

	/**
	 * @notice Gets balance of this contract in terms of the underlying
	 * @dev This excludes the value of the current message, if any
	 * @return The quantity of underlying tokens owned by this contract
	 */
	function getCashPrior() internal override view returns (uint256) {
		EIP20Interface token = EIP20Interface(underlying);
		return token.balanceOf(address(this));
	}

	/**
	 * @dev Similar to EIP20 transfer, except it handles a False result from `transferFrom` and reverts in that case.
	 *      This will revert due to insufficient balance or insufficient allowance.
	 *      This function returns the actual amount received,
	 *      which may be less than `amount` if there is a fee attached to the transfer.
	 *
	 *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
	 *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
	 */
	function doTransferIn(address from, uint256 amount) internal override returns (uint256) {
		EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying);
		uint256 balanceBefore = EIP20Interface(underlying).balanceOf(address(this));
		token.transferFrom(from, address(this), amount);

		bool success;
		assembly {
			switch returndatasize()
				case 0 {
					// This is a non-standard ERC-20
					success := not(0) // set success to true
				}
				case 32 {
					// This is a compliant ERC-20
					returndatacopy(0, 0, 32)
					success := mload(0) // Set `success = returndata` of external call
				}
				default {
					// This is an excessively non-compliant ERC-20, revert.
					revert(0, 0)
				}
		}
		require(success, "TOKEN_TRANSFER_IN_FAILED");

		// Calculate the amount that was *actually* transferred
		uint256 balanceAfter = EIP20Interface(underlying).balanceOf(address(this));
		require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
		return balanceAfter - balanceBefore; // underflow already checked above, just subtract
	}

	/**
	 * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
	 *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
	 *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
	 *      it is >= amount, this should not revert in normal conditions.
	 *
	 *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
	 *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
	 */
	function doTransferOut(address payable to, uint256 amount) internal override {
		EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying);
		token.transfer(to, amount);

		bool success;
		assembly {
			switch returndatasize()
				case 0 {
					// This is a non-standard ERC-20
					success := not(0) // set success to true
				}
				case 32 {
					// This is a complaint ERC-20
					returndatacopy(0, 0, 32)
					success := mload(0) // Set `success = returndata` of external call
				}
				default {
					// This is an excessively non-compliant ERC-20, revert.
					revert(0, 0)
				}
		}
		require(success, "TOKEN_TRANSFER_OUT_FAILED");
	}

	/**
	 * @notice The sender adds to reserves.
	 * @param addAmount The amount fo underlying token to add as reserves
	 * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
	 */
	function _addReserves(uint256 addAmount) external override returns (uint256) {
		return _addReservesInternal(addAmount);
	}

	function _mintDOL(uint256 amount) external returns (uint256) {
		require(msg.sender == address(controller), "only admin can expand DOL supply");
		require(Strings.equals(symbol, "hDOL"), "only hDOL can be expanded the supply");

		uint256 error = accrueInterestInternal();
		if (error != uint256(Error.NO_ERROR)) {
			// accrueInterest emits logs on errors, but we still want to log the fact that an attempted borrow failed
			return fail(Error(error), FailureInfo.MINT_ACCRUE_INTEREST_FAILED);
		}

		/* Verify market's block number equals current block number */
		if (accrualBlockNumber != getBlockNumber()) {
			return fail(Error.MARKET_NOT_FRESH, FailureInfo.MINT_FRESHNESS_CHECK);
		}

		MintLocalVars memory vars;

		(vars.mathErr, vars.exchangeRateMantissa) = exchangeRateStoredInternal();
		if (vars.mathErr != MathError.NO_ERROR) {
			return failOpaque(Error.MATH_ERROR, FailureInfo.MINT_EXCHANGE_RATE_READ_FAILED, uint256(vars.mathErr));
		}

		/////////////////////////
		// EFFECTS & INTERACTIONS
		// (No safe failures beyond this point)
		address minter = msg.sender;

		vars.actualMintAmount = doTransferIn(minter, amount);

		/*
		 * We get the current exchange rate and calculate the number of hTokens to be minted:
		 *  mintTokens = actualMintAmount / exchangeRate
		 */

		(vars.mathErr, vars.mintTokens) = divScalarByExpTruncate(
			vars.actualMintAmount,
			Exp({ mantissa: vars.exchangeRateMantissa })
		);
		require(vars.mathErr == MathError.NO_ERROR, "MINT_EXCHANGE_CALCULATION_FAILED");

		/*
		 * We calculate the new total supply of hTokens and minter token balance, checking for overflow:
		 *  totalSupplyNew = totalSupply + mintTokens
		 *  accountTokensNew = accountTokens[minter] + mintTokens
		 */
		(vars.mathErr, vars.totalSupplyNew) = addUInt(totalSupply, vars.mintTokens);
		require(vars.mathErr == MathError.NO_ERROR, "MINT_NEW_TOTAL_SUPPLY_CALCULATION_FAILED");

		(vars.mathErr, vars.accountTokensNew) = addUInt(accountTokens[minter], vars.mintTokens);
		require(vars.mathErr == MathError.NO_ERROR, "MINT_NEW_ACCOUNT_BALANCE_CALCULATION_FAILED");

		/* We emit a Mint event, and a Transfer event */
		emit Mint(minter, vars.actualMintAmount, vars.mintTokens);
		emit Transfer(address(this), minter, vars.mintTokens);

		/* We write previously calculated values into storage */
		totalSupply = vars.totalSupplyNew;
		accountTokens[minter] = vars.accountTokensNew;

		/* We call the defense hook */
		controller.mintVerify(address(this), minter, vars.actualMintAmount, vars.mintTokens);

		return uint256(Error.NO_ERROR);
	}

	function _redeemDOL(uint256 amount) external returns (uint256) {
		require(msg.sender == address(controller), "only admin can reduce DOL supply");
		require(Strings.equals(symbol, "hDOL"), "only hDOL can be reduced the supply");

		uint256 error = accrueInterestInternal();
		if (error != uint256(Error.NO_ERROR)) {
			// accrueInterest emits logs on errors, but we still want to log the fact that an attempted borrow failed
			return fail(Error(error), FailureInfo.MINT_ACCRUE_INTEREST_FAILED);
		}

		/* Verify market's block number equals current block number */
		if (accrualBlockNumber != getBlockNumber()) {
			return fail(Error.MARKET_NOT_FRESH, FailureInfo.MINT_FRESHNESS_CHECK);
		}

		RedeemLocalVars memory vars;

		/* exchangeRate = invoke Exchange Rate Stored() */
		(vars.mathErr, vars.exchangeRateMantissa) = exchangeRateStoredInternal();
		if (vars.mathErr != MathError.NO_ERROR) {
			return failOpaque(Error.MATH_ERROR, FailureInfo.REDEEM_EXCHANGE_RATE_READ_FAILED, uint256(vars.mathErr));
		}

		(vars.mathErr, vars.redeemTokens) = divScalarByExpTruncate(amount, Exp({ mantissa: vars.exchangeRateMantissa }));
		if (vars.mathErr != MathError.NO_ERROR) {
			return failOpaque(Error.MATH_ERROR, FailureInfo.REDEEM_EXCHANGE_AMOUNT_CALCULATION_FAILED, uint256(vars.mathErr));
		}

		vars.redeemAmount = amount;

		/*
		 * We calculate the new total supply and redeemer balance, checking for underflow:
		 *  totalSupplyNew = totalSupply - redeemTokens
		 *  accountTokensNew = accountTokens[redeemer] - redeemTokens
		 */
		(vars.mathErr, vars.totalSupplyNew) = subUInt(totalSupply, vars.redeemTokens);
		if (vars.mathErr != MathError.NO_ERROR) {
			return
				failOpaque(Error.MATH_ERROR, FailureInfo.REDEEM_NEW_TOTAL_SUPPLY_CALCULATION_FAILED, uint256(vars.mathErr));
		}

		address payable redeemer = msg.sender;
		(vars.mathErr, vars.accountTokensNew) = subUInt(accountTokens[redeemer], vars.redeemTokens);
		if (vars.mathErr != MathError.NO_ERROR) {
			return
				failOpaque(Error.MATH_ERROR, FailureInfo.REDEEM_NEW_ACCOUNT_BALANCE_CALCULATION_FAILED, uint256(vars.mathErr));
		}

		/* Fail gracefully if protocol has insufficient cash */
		if (getCashPrior() < vars.redeemAmount) {
			return fail(Error.TOKEN_INSUFFICIENT_CASH, FailureInfo.REDEEM_TRANSFER_OUT_NOT_POSSIBLE);
		}

		/////////////////////////
		// EFFECTS & INTERACTIONS
		// (No safe failures beyond this point)

		/*
		 * We invoke doTransferOut for the redeemer and the redeemAmount.
		 *  Note: The hToken must handle variations between ERC-20 and ETH underlying.
		 *  On success, the hToken has redeemAmount less of cash.
		 *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
		 */
		doTransferOut(redeemer, vars.redeemAmount);

		/* We write previously calculated values into storage */
		totalSupply = vars.totalSupplyNew;
		accountTokens[redeemer] = vars.accountTokensNew;

		/* We emit a Transfer event, and a Redeem event */
		emit Transfer(redeemer, address(this), vars.redeemTokens);
		emit Redeem(redeemer, vars.redeemAmount, vars.redeemTokens);

		/* We call the defense hook */
		controller.redeemVerify(address(this), redeemer, vars.redeemTokens, vars.redeemAmount);

		return uint256(Error.NO_ERROR);
	}
}
