pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface DistributorInterface {
	struct AccountRecord {
		uint256 power;
		uint256 mask;
		uint256 settled;
		uint256 claimed;
	}

	struct TokenPoolMeta {
		uint256 rewardIndex;
		uint256 lastBlockNumber;
		int256 accumulatedPower;
		uint256 accumulatedTokens;
		uint256 totalPower;
	}

	struct LiquidityProviderPoolMeta {
		uint32 id;
		address lpToken;
		uint256 startBlock;
		uint256 endBlock;
		uint256 tokensPerBlock;
		uint256 rewardIndex;
		uint256 lastBlockNumber;
		int256 accumulatedPower;
		uint256 accumulatedTokens;
		uint256 totalPower;
	}

	struct TokenPool {
		uint256 rewardIndex;
		uint256 lastBlockNumber;
		int256 accumulatedPower;
		uint256 accumulatedTokens;
		uint256 totalPower;
		mapping(address => AccountRecord) accountRecords;
	}

	struct LiquidityProviderPool {
		TokenPool base;
		uint32 id;
		address lpToken;
		uint256 startBlock;
		uint256 endBlock;
		uint256 tokensPerBlock;
	}

	function initialize(
		address admin,
		address token,
		address oracle,
		address superior
	) external;

	function increaseSupply(
		address account,
		address hToken,
		uint256 amount
	) external returns (uint256);

	function decreaseSupply(
		address account,
		address hToken,
		uint256 amount,
		uint256 left
	) external returns (uint256);

	function increaseBorrow(
		address account,
		address hToken,
		uint256 amount
	) external returns (uint256);

	function decreaseBorrow(
		address account,
		address hToken,
		uint256 amount,
		uint256 left
	) external returns (uint256);

	function createLPPool(
		address lpToken,
		uint256 startBlock,
		uint256 endBlock,
		uint256 tokensPerBlock
	) external returns (uint32);

	function mintLPPool(uint32 id, uint256 amount) external;

	function claimMainPool() external returns (uint256);

	function claimLPPool(uint32 id) external returns (uint256);

	function exitLPPool(uint32 id, bool isClaim) external;

	function getMainPoolMetadata() external view returns (TokenPoolMeta memory);

	function getAllLPPools() external view returns (LiquidityProviderPoolMeta[] memory);

	function getAccountRecordInPool(address account, int32 pool) external view returns (AccountRecord memory);
}
