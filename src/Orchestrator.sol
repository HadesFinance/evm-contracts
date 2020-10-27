pragma solidity ^0.6.0;

import "./libraries/openzeppelin-upgradeability/InitializableAdminUpgradeabilityProxy.sol";
import "./interfaces/DistributorInterface.sol";
import "./interfaces/InterestRateStrategyInterface.sol";
import "./interfaces/MarketControllerInterface.sol";
import "./interfaces/PriceOracleInterface.sol";
import "./HDS.sol";
import "./DOL.sol";
import "./Governance.sol";
import "./ProtocolReporter.sol";
import "./Timelock.sol";
import "./HEther.sol";
import "./HErc20.sol";

contract Orchestrator {
	mapping(bytes32 => address) private addresses;

	bytes32 private constant ADDR_HDS = "ADDR_HDS";
	bytes32 private constant ADDR_DOL = "ADDR_DOL";
	bytes32 private constant ADDR_ORACLE = "ADDR_ORACLE";
	bytes32 private constant ADDR_INTEREST_RATE_STRATEGY = "ADDR_INTEREST_RATE_STRATEGY";
	bytes32 private constant ADDR_MARKET_CONTROLLER = "ADDR_MARKET_CONTROLLER";
	bytes32 private constant ADDR_DISTRIBUTOR = "ADDR_DISTRIBUTOR";
	bytes32 private constant ADDR_TIMELOCK = "ADDR_TIMELOCK";
	bytes32 private constant ADDR_GOVERN = "ADDR_GOVERN";
	bytes32 private constant ADDR_REPORTER = "ADDR_REPORTER";

	HDS public hds;
	DOL public dol;
	DistributorInterface public distributor;
	PriceOracleInterface public oracle;
	InterestRateStrategyInterface public interestRateStrategy;
	MarketControllerInterface public controller;
	Timelock public timelock;
	Governance public govern;
	ProtocolReporter public reporter;

	address payable public admin;

	event ProxyCreated(bytes32 id, address indexed newAddress);

	function initialize(
		address[] calldata impls,
		address _hds,
		address payable _hEther,
		address _hDol
	) external {
		require(impls.length == 8, "should have exactly 8 implementation addresses");
		admin = msg.sender;

		address _dol = impls[0];
		oracle = PriceOracleInterface(updateImplInternal(ADDR_ORACLE, impls[1]));
		interestRateStrategy = InterestRateStrategyInterface(updateImplInternal(ADDR_INTEREST_RATE_STRATEGY, impls[2]));
		controller = MarketControllerInterface(updateImplInternal(ADDR_MARKET_CONTROLLER, impls[3]));
		distributor = DistributorInterface(updateImplInternal(ADDR_DISTRIBUTOR, impls[4]));
		timelock = Timelock(updateImplInternal(ADDR_TIMELOCK, impls[5]));
		govern = Governance(updateImplInternal(ADDR_GOVERN, impls[6]));
		reporter = ProtocolReporter(updateImplInternal(ADDR_REPORTER, impls[7]));

		hds = HDS(_hds);
		setAddress(ADDR_HDS, _hds);

		dol = DOL(_dol);
		setAddress(ADDR_DOL, _dol);

		distributor.initialize(admin, _hds, address(oracle), address(controller));
		controller.initialize(admin, address(this), address(distributor));
		dol.initialize(address(controller));
		// hds should be deployed separated and will be initialized by the administrator
		// hds.initialize(address(distributor));
		timelock.initialize(admin);
		govern.initialize(admin, address(timelock), address(hds));

		HEther hEther = HEther(_hEther);
		hEther.initialize(admin, controller, interestRateStrategy, distributor, "Hades wrapped ETH", "hETH");

		HErc20 hDol = HErc20(_hDol);
		hDol.initialize(
			admin,
			_dol,
			controller,
			interestRateStrategy,
			distributor,
			"Hades wrapped DOL",
			"hDOL",
			"USD"
		);

		controller._supportMarket(_hEther);
		controller._supportMarket(_hDol);
	}

	function addToken(
		address hTokenAddr,
		address underlyingAddr,
		string calldata name,
		string calldata symbol,
		string calldata anchor
	) external {
		HErc20 hToken = HErc20(hTokenAddr);
		hToken.initialize(admin, underlyingAddr, controller, interestRateStrategy, distributor, name, symbol, anchor);
		controller._supportMarket(hTokenAddr);
	}

	function getHDS() external view returns (address) {
		return getAddress(ADDR_HDS);
	}

	function getDOL() external view returns (address) {
		return getAddress(ADDR_DOL);
	}

	function getOracle() external view returns (address) {
		return getAddress(ADDR_ORACLE);
	}

	function setOracleImpl(address _oracle) external returns (address) {
		address proxy = updateImplInternal(ADDR_ORACLE, _oracle);
		return proxy;
	}

	function getInterestRateStrategy() external view returns (address) {
		return getAddress(ADDR_INTEREST_RATE_STRATEGY);
	}

	function setInterestRateStrategyImpl(address _interestRateStrategy) external returns (address) {
		address proxy = updateImplInternal(ADDR_INTEREST_RATE_STRATEGY, _interestRateStrategy);
		return proxy;
	}

	function getMarketController() external view returns (address) {
		return getAddress(ADDR_MARKET_CONTROLLER);
	}

	function setMarketControllerImpl(address _controller) external returns (address) {
		address proxy = updateImplInternal(ADDR_MARKET_CONTROLLER, _controller);
		return proxy;
	}

	function getHDistributor() external view returns (address) {
		return getAddress(ADDR_DISTRIBUTOR);
	}

	function setDistributorImpl(address _distributor) external returns (address) {
		address proxy = updateImplInternal(ADDR_DISTRIBUTOR, _distributor);
		return proxy;
	}

	function getGovern() external view returns (address) {
		return getAddress(ADDR_GOVERN);
	}

	function setGovernImpl(address _govern) external returns (address) {
		address proxy = updateImplInternal(ADDR_GOVERN, _govern);
		return proxy;
	}

	function getReporter() external view returns (address) {
		return getAddress(ADDR_REPORTER);
	}

	function setReporter(address _reporter) external returns (address) {
		address proxy = updateImplInternal(ADDR_REPORTER, _reporter);
		return proxy;
	}

	function getTimelock() external view returns (address) {
		return getAddress(ADDR_TIMELOCK);
	}

	function setTimelock(address _timelock) external returns (address) {
		address proxy = updateImplInternal(ADDR_TIMELOCK, _timelock);
		return proxy;
	}

	function getAddress(bytes32 _key) internal view returns (address) {
		return addresses[_key];
	}

	function setAddress(bytes32 _key, address _value) internal {
		addresses[_key] = _value;
	}

	/**
	 * @dev internal function to update the implementation of a specific component of the protocol
	 * @param _id the id of the contract to be updated
	 * @param _newAddress the address of the new implementation
	 **/
	function updateImplInternal(bytes32 _id, address _newAddress) internal returns (address payable) {
		address payable proxyAddress = address(uint160(getAddress(_id)));

		InitializableAdminUpgradeabilityProxy proxy = InitializableAdminUpgradeabilityProxy(proxyAddress);
		// bytes memory params = abi.encodeWithSignature("initialize(address)", address(this));
		bytes memory params = new bytes(0);

		if (proxyAddress == address(0)) {
			proxy = new InitializableAdminUpgradeabilityProxy();
			proxy.initialize(_newAddress, admin, params);
			setAddress(_id, address(proxy));
			emit ProxyCreated(_id, address(proxy));
		} else {
			// proxy.upgradeToAndCall(_newAddress, params);
			proxy.upgradeTo(_newAddress);
		}
		return address(uint160(getAddress(_id)));
	}
}
