// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../src/MiniPaySpendGuard.sol";

interface Vm {
    function envUint(string calldata name) external returns (uint256);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract DeployCelo {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (MiniPaySpendGuard guard) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        guard = new MiniPaySpendGuard();
        vm.stopBroadcast();
    }
}
