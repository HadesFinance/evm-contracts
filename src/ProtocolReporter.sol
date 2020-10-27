pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./interfaces/EIP20Interface.sol";
import "./interfaces/PriceOracleInterface.sol";
import "./HErc20.sol";
import "./HToken.sol";
import "./Governance.sol";
import "./HDS.sol";

interface MarketControllerLensInterface {
	function markets(address) external view returns (bool, uint256);

	function oracle() external view returns (PriceOracleInterface);

	function getAccountLiquidity(address)
		external
		view
		returns (
			uint256,
			uint256,
			uint256
		);

	function getAssetsIn(address) external view returns (HToken[] memory);

	function claimComp(address) external;

	function compAccrued(address) external view returns (uint256);
}

contract ProtocolReporter {
	struct HTokenMetadata {
		address hToken;
		uint256 exchangeRateCurrent;
		uint256 supplyRatePerBlock;
		uint256 borrowRatePerBlock;
		uint256 reserveFactorMantissa;
		uint256 totalBorrows;
		uint256 totalReserves;
		uint256 totalSupply;
		uint256 totalCash;
		bool isListed;
		uint256 collateralFactorMantissa;
		address underlyingAssetAddress;
		uint256 hTokenDecimals;
		uint256 underlyingDecimals;
	}

	function hTokenMetadata(HToken hToken) public view returns (HTokenMetadata memory) {
		uint256 exchangeRateCurrent = hToken.exchangeRateCurrent();
		MarketControllerLensInterface controller = MarketControllerLensInterface(address(hToken.controller()));
		(bool isListed, uint256 collateralFactorMantissa) = controller.markets(address(hToken));
		address underlyingAssetAddress;
		uint256 underlyingDecimals;

		if (compareStrings(hToken.symbol(), "cETH")) {
			underlyingAssetAddress = address(0);
			underlyingDecimals = 18;
		} else {
			HErc20 hErc20 = HErc20(address(hToken));
			underlyingAssetAddress = hErc20.underlying();
			underlyingDecimals = EIP20Interface(hErc20.underlying()).decimals();
		}

		return
			HTokenMetadata({
				hToken: address(hToken),
				exchangeRateCurrent: exchangeRateCurrent,
				supplyRatePerBlock: hToken.supplyRatePerBlock(),
				borrowRatePerBlock: hToken.borrowRatePerBlock(),
				reserveFactorMantissa: hToken.reserveFactorMantissa(),
				totalBorrows: hToken.totalBorrows(),
				totalReserves: hToken.totalReserves(),
				totalSupply: hToken.totalSupply(),
				totalCash: hToken.getCash(),
				isListed: isListed,
				collateralFactorMantissa: collateralFactorMantissa,
				underlyingAssetAddress: underlyingAssetAddress,
				hTokenDecimals: hToken.decimals(),
				underlyingDecimals: underlyingDecimals
			});
	}

	function hTokenMetadataAll(HToken[] calldata hTokens) external view returns (HTokenMetadata[] memory) {
		uint256 hTokenCount = hTokens.length;
		HTokenMetadata[] memory res = new HTokenMetadata[](hTokenCount);
		for (uint256 i = 0; i < hTokenCount; i++) {
			res[i] = hTokenMetadata(hTokens[i]);
		}
		return res;
	}

	struct HTokenBalances {
		address hToken;
		uint256 balanceOf;
		uint256 borrowBalanceCurrent;
		uint256 balanceOfUnderlying;
		uint256 tokenBalance;
		uint256 tokenAllowance;
	}

	function hTokenBalances(HToken hToken, address payable account) public returns (HTokenBalances memory) {
		uint256 balanceOf = hToken.balanceOf(account);
		uint256 borrowBalanceCurrent = hToken.borrowBalanceCurrent(account);
		uint256 balanceOfUnderlying = hToken.balanceOfUnderlying(account);
		uint256 tokenBalance;
		uint256 tokenAllowance;

		if (compareStrings(hToken.symbol(), "cETH")) {
			tokenBalance = account.balance;
			tokenAllowance = account.balance;
		} else {
			HErc20 hErc20 = HErc20(address(hToken));
			EIP20Interface underlying = EIP20Interface(hErc20.underlying());
			tokenBalance = underlying.balanceOf(account);
			tokenAllowance = underlying.allowance(account, address(hToken));
		}

		return
			HTokenBalances({
				hToken: address(hToken),
				balanceOf: balanceOf,
				borrowBalanceCurrent: borrowBalanceCurrent,
				balanceOfUnderlying: balanceOfUnderlying,
				tokenBalance: tokenBalance,
				tokenAllowance: tokenAllowance
			});
	}

	function hTokenBalancesAll(HToken[] calldata hTokens, address payable account)
		external
		returns (HTokenBalances[] memory)
	{
		uint256 hTokenCount = hTokens.length;
		HTokenBalances[] memory res = new HTokenBalances[](hTokenCount);
		for (uint256 i = 0; i < hTokenCount; i++) {
			res[i] = hTokenBalances(hTokens[i], account);
		}
		return res;
	}

	struct HTokenUnderlyingPrice {
		address hToken;
		uint256 underlyingPrice;
	}

	function hTokenUnderlyingPrice(HToken hToken) public view returns (HTokenUnderlyingPrice memory) {
		MarketControllerLensInterface controller = MarketControllerLensInterface(address(hToken.controller()));
		PriceOracleInterface oracle = controller.oracle();

		return
			HTokenUnderlyingPrice({ hToken: address(hToken), underlyingPrice: oracle.getUnderlyingPrice(address(hToken)) });
	}

	function hTokenUnderlyingPriceAll(HToken[] calldata hTokens) external view returns (HTokenUnderlyingPrice[] memory) {
		uint256 hTokenCount = hTokens.length;
		HTokenUnderlyingPrice[] memory res = new HTokenUnderlyingPrice[](hTokenCount);
		for (uint256 i = 0; i < hTokenCount; i++) {
			res[i] = hTokenUnderlyingPrice(hTokens[i]);
		}
		return res;
	}

	struct AccountLimits {
		HToken[] markets;
		uint256 liquidity;
		uint256 shortfall;
	}

	function getAccountLimits(MarketControllerLensInterface controller, address account)
		public
		view
		returns (AccountLimits memory)
	{
		(uint256 errorCode, uint256 liquidity, uint256 shortfall) = controller.getAccountLiquidity(account);
		require(errorCode == 0, "Failed to get account liquidity");

		return AccountLimits({ markets: controller.getAssetsIn(account), liquidity: liquidity, shortfall: shortfall });
	}

	struct GovReceipt {
		uint256 proposalId;
		bool hasVoted;
		bool support;
		uint96 votes;
	}

	function getGovReceipts(
		Governance governor,
		address voter,
		uint256[] memory proposalIds
	) public view returns (GovReceipt[] memory) {
		uint256 proposalCount = proposalIds.length;
		GovReceipt[] memory res = new GovReceipt[](proposalCount);
		for (uint256 i = 0; i < proposalCount; i++) {
			Governance.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
			res[i] = GovReceipt({
				proposalId: proposalIds[i],
				hasVoted: receipt.hasVoted,
				support: receipt.support,
				votes: receipt.votes
			});
		}
		return res;
	}

	struct GovProposal {
		uint256 proposalId;
		address proposer;
		uint256 eta;
		address[] targets;
		uint256[] values;
		string[] signatures;
		bytes[] calldatas;
		uint256 startBlock;
		uint256 endBlock;
		uint256 forVotes;
		uint256 againstVotes;
		bool canceled;
		bool executed;
	}

	function setProposal(
		GovProposal memory res,
		Governance governor,
		uint256 proposalId
	) internal view {
		(
			,
			address proposer,
			uint256 eta,
			uint256 startBlock,
			uint256 endBlock,
			uint256 forVotes,
			uint256 againstVotes,
			bool canceled,
			bool executed
		) = governor.proposals(proposalId);
		res.proposalId = proposalId;
		res.proposer = proposer;
		res.eta = eta;
		res.startBlock = startBlock;
		res.endBlock = endBlock;
		res.forVotes = forVotes;
		res.againstVotes = againstVotes;
		res.canceled = canceled;
		res.executed = executed;
	}

	function getGovProposals(Governance governor, uint256[] calldata proposalIds)
		external
		view
		returns (GovProposal[] memory)
	{
		GovProposal[] memory res = new GovProposal[](proposalIds.length);
		for (uint256 i = 0; i < proposalIds.length; i++) {
			(
				address[] memory targets,
				uint256[] memory values,
				string[] memory signatures,
				bytes[] memory calldatas
			) = governor.getActions(proposalIds[i]);
			res[i] = GovProposal({
				proposalId: 0,
				proposer: address(0),
				eta: 0,
				targets: targets,
				values: values,
				signatures: signatures,
				calldatas: calldatas,
				startBlock: 0,
				endBlock: 0,
				forVotes: 0,
				againstVotes: 0,
				canceled: false,
				executed: false
			});
			setProposal(res[i], governor, proposalIds[i]);
		}
		return res;
	}

	struct CompBalanceMetadata {
		uint256 balance;
		uint256 votes;
		address delegate;
	}

	function getCompBalanceMetadata(HDS hds, address account) external view returns (CompBalanceMetadata memory) {
		return
			CompBalanceMetadata({
				balance: hds.balanceOf(account),
				votes: uint256(hds.getCurrentVotes(account)),
				delegate: hds.delegates(account)
			});
	}

	struct CompBalanceMetadataExt {
		uint256 balance;
		uint256 votes;
		address delegate;
		uint256 allocated;
	}

	function getCompBalanceMetadataExt(
		HDS hds,
		MarketControllerLensInterface controller,
		address account
	) external returns (CompBalanceMetadataExt memory) {
		uint256 balance = hds.balanceOf(account);
		controller.claimComp(account);
		uint256 newBalance = hds.balanceOf(account);
		uint256 accrued = controller.compAccrued(account);
		uint256 total = add(accrued, newBalance, "sum comp total");
		uint256 allocated = sub(total, balance, "sub allocated");

		return
			CompBalanceMetadataExt({
				balance: balance,
				votes: uint256(hds.getCurrentVotes(account)),
				delegate: hds.delegates(account),
				allocated: allocated
			});
	}

	struct CompVotes {
		uint256 blockNumber;
		uint256 votes;
	}

	function getCompVotes(
		HDS hds,
		address account,
		uint32[] calldata blockNumbers
	) external view returns (CompVotes[] memory) {
		CompVotes[] memory res = new CompVotes[](blockNumbers.length);
		for (uint256 i = 0; i < blockNumbers.length; i++) {
			res[i] = CompVotes({
				blockNumber: uint256(blockNumbers[i]),
				votes: uint256(hds.getPriorVotes(account, blockNumbers[i]))
			});
		}
		return res;
	}

	function compareStrings(string memory a, string memory b) internal pure returns (bool) {
		return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
	}

	function add(
		uint256 a,
		uint256 b,
		string memory errorMessage
	) internal pure returns (uint256) {
		uint256 c = a + b;
		require(c >= a, errorMessage);
		return c;
	}

	function sub(
		uint256 a,
		uint256 b,
		string memory errorMessage
	) internal pure returns (uint256) {
		require(b <= a, errorMessage);
		uint256 c = a - b;
		return c;
	}
}
