// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        // Seplolia chain ID
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    // for Sepolia network
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // 30 seconds
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, // from the Chainlink documentation (https://docs.chain.link/vrf/v2/subscription/supported-networks)
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // Key Hash from the Chainlink documentation (https://docs.chain.link/vrf/v2/subscription/supported-networks)
                subscriptionId: 0,
                callbackGasLimit: 500000, // 500,000 gas
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789 // LINK token address
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether; // 0.25 LINK
        uint96 gasPriceLink = 1e9; // 1 gwei LINK

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken(); // <<<<<
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // 30 seconds
                vrfCoordinator: address(vrfCoordinatorMock),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0, // our script will add this
                callbackGasLimit: 500000, // 500,000 gas
                link: address(link)
            });
    }
}
