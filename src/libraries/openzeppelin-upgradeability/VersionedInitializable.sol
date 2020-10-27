pragma solidity ^0.6.0;

/**
 * @title VersionedInitializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 *
 * @author Aave, inspired by the OpenZeppelin Initializable contract
 */
abstract contract VersionedInitializable {
	/**
	 * @dev Indicates that the contract has been initialized.
	 */
	uint256 private lastInitializedRevision = 0;

	/**
	 * @dev Indicates that the contract is in the process of being initialized.
	 */
	bool private initializing;

	/**
	 * @dev Modifier to use in the initializer function of a contract.
	 */
	modifier initializer() {
		uint256 revision = getRevision();
		require(initializing || revision > lastInitializedRevision, "Contract instance has already been initialized");

		bool isTopLevelCall = !initializing;
		if (isTopLevelCall) {
			initializing = true;
			lastInitializedRevision = revision;
		}

		_;

		if (isTopLevelCall) {
			initializing = false;
		}
	}

	/// @dev returns the revision number of the contract.
	/// Needs to be defined in the inherited class as a constant.
	function getRevision() internal virtual pure returns (uint256);

	// Reserved storage space to allow for layout changes in the future.
	uint256[50] private ______gap;
}
