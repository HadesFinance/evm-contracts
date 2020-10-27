pragma solidity ^0.6.0;

library Strings {
	function equals(string memory _a, string memory _b) internal pure returns (bool) {
		// return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
		bytes memory a = bytes(_a);
		bytes memory b = bytes(_b);
		if (a.length != b.length) {
			return false;
		}
		for (uint16 i; i < a.length; i++) {
			if (a[i] != b[i]) {
				return false;
			}
		}
		return true;
	}
}
