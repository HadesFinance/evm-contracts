pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract DOL {
	/// @notice EIP-20 token name for this token
	string public constant name = "DOL Stablecoin";

	/// @notice EIP-20 token symbol for this token
	string public constant symbol = "DOL";

	/// @notice EIP-20 token decimals for this token
	uint8 public constant decimals = 8;

	/// @notice Total number of tokens in circulation
	uint96 public totalSupply;

	/// @notice Allowance amounts on behalf of others
	mapping(address => mapping(address => uint96)) internal allowances;

	/// @notice Official record of token balances for each account
	mapping(address => uint96) internal balances;

	/// @notice The EIP-712 typehash for the contract's domain
	bytes32 public constant DOMAIN_TYPEHASH = keccak256(
		"EIP712Domain(string name,uint256 chainId,address verifyingContract)"
	);

	/// @notice The EIP-712 typehash for the delegation struct used by the contract
	bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

	/// @notice The market controller address that have the auth to mint or burn tokens
	address public superior;

	/// @notice The standard EIP-20 transfer event
	event Transfer(address indexed from, address indexed to, uint256 amount);

	/// @notice The standard EIP-20 approval event
	event Approval(address indexed owner, address indexed spender, uint256 amount);

	/// @notice For safety auditor: the superior should be the deployed MarketController contract address
	modifier onlySuperior {
		require(superior == msg.sender, "The caller must be a superior contract");
		_;
	}

	function initialize(address _superior) external {
		superior = _superior;
	}

	/**
	 * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
	 * @param account The address of the account holding the funds
	 * @param spender The address of the account spending the funds
	 * @return The number of tokens approved
	 */
	function allowance(address account, address spender) external view returns (uint256) {
		return allowances[account][spender];
	}

	/**
	 * @notice Approve `spender` to transfer up to `amount` from `src`
	 * @dev This will overwrite the approval amount for `spender`
	 *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
	 * @param spender The address of the account which may transfer tokens
	 * @param rawAmount The number of tokens that are approved (2^256-1 means infinite)
	 * @return Whether or not the approval succeeded
	 */
	function approve(address spender, uint256 rawAmount) external returns (bool) {
		uint96 amount;
		if (rawAmount == uint256(-1)) {
			amount = uint96(-1);
		} else {
			amount = safe96(rawAmount, "HDS::approve: amount exceeds 96 bits");
		}

		allowances[msg.sender][spender] = amount;

		emit Approval(msg.sender, spender, amount);
		return true;
	}

	/**
	 * @notice Get the number of tokens held by the `account`
	 * @param account The address of the account to get the balance of
	 * @return The number of tokens held
	 */
	function balanceOf(address account) external view returns (uint256) {
		return balances[account];
	}

	/**
	 * @notice Transfer `amount` tokens from `msg.sender` to `dst`
	 * @param dst The address of the destination account
	 * @param rawAmount The number of tokens to transfer
	 * @return Whether or not the transfer succeeded
	 */
	function transfer(address dst, uint256 rawAmount) external returns (bool) {
		uint96 amount = safe96(rawAmount, "HDS::transfer: amount exceeds 96 bits");
		_transferTokens(msg.sender, dst, amount);
		return true;
	}

	/**
	 * @notice Transfer `amount` tokens from `src` to `dst`
	 * @param src The address of the source account
	 * @param dst The address of the destination account
	 * @param rawAmount The number of tokens to transfer
	 * @return Whether or not the transfer succeeded
	 */
	function transferFrom(
		address src,
		address dst,
		uint256 rawAmount
	) external returns (bool) {
		address spender = msg.sender;
		uint96 spenderAllowance = allowances[src][spender];
		uint96 amount = safe96(rawAmount, "HDS::approve: amount exceeds 96 bits");

		if (spender != src && spenderAllowance != uint96(-1)) {
			uint96 newAllowance = sub96(
				spenderAllowance,
				amount,
				"HDS::transferFrom: transfer amount exceeds spender allowance"
			);
			allowances[src][spender] = newAllowance;
		}

		_transferTokens(src, dst, amount);
		return true;
	}

	/**
	 * @notice Mint `amount` tokens for 'account'
	 * @param account The address to receive the mint tokens
	 * @param rawAmount The number of tokens to mint
	 */
	function mint(address account, uint256 rawAmount) external onlySuperior {
		// TODO auth validate
		uint96 amount = safe96(rawAmount, "HDS::mint: amount exceeds 96 bits");
		balances[account] = add96(balances[account], amount, "HDS::mint: balance overflows");
		totalSupply = add96(totalSupply, amount, "HDS::mint: totalSupply overflows");
		emit Transfer(address(0), account, amount);
	}

	/**
	 * @notice Burn `amount` tokens for 'account'
	 * @param account The address to burn tokens
	 * @param rawAmount The number of tokens to burn
	 */
	function burn(address account, uint256 rawAmount) external {
		uint96 amount = safe96(rawAmount, "HDS::burn: amount exceeds 96 bits");
		address spender = msg.sender;
		if (account != spender) {
			uint96 spenderAllowance = allowances[account][spender];
			if (spenderAllowance != uint96(-1)) {
				uint96 newAllowance = sub96(spenderAllowance, amount, "HDS::burn: burn amount exceeds spender allowance");
				allowances[account][spender] = newAllowance;
			}
		}
		balances[account] = sub96(balances[account], amount, "HDS::burn: burn amount exceeds balance");
		totalSupply = sub96(totalSupply, amount, "HDS::burn: burn amount exceeds totalSupply");
		emit Transfer(account, address(0), amount);
	}

	function _transferTokens(
		address src,
		address dst,
		uint96 amount
	) internal {
		require(src != address(0), "HDS::_transferTokens: cannot transfer from the zero address");
		require(dst != address(0), "HDS::_transferTokens: cannot transfer to the zero address");

		balances[src] = sub96(balances[src], amount, "HDS::_transferTokens: transfer amount exceeds balance");
		balances[dst] = add96(balances[dst], amount, "HDS::_transferTokens: transfer amount overflows");
		emit Transfer(src, dst, amount);
	}

	function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
		require(n < 2**32, errorMessage);
		return uint32(n);
	}

	function safe96(uint256 n, string memory errorMessage) internal pure returns (uint96) {
		require(n < 2**96, errorMessage);
		return uint96(n);
	}

	function add96(
		uint96 a,
		uint96 b,
		string memory errorMessage
	) internal pure returns (uint96) {
		uint96 c = a + b;
		require(c >= a, errorMessage);
		return c;
	}

	function sub96(
		uint96 a,
		uint96 b,
		string memory errorMessage
	) internal pure returns (uint96) {
		require(b <= a, errorMessage);
		return a - b;
	}
}
