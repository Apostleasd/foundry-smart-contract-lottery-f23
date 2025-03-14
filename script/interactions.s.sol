// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperconfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployKey) = helperconfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployKey
    ) public returns (uint64) {
        console.log("Creating subscription on chainId", block.chainid);
        vm.startBroadcast(deployKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription created with id", subId);
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperconfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 sunId,
            ,
            address link,
            uint256 deployKey
        ) = helperconfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, sunId, link, deployKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 sunId,
        address link,
        uint256 deployKey
    ) public {
        console.log("Funding subscription: ", sunId);
        console.log("Uing vrfCoordinator: ", vrfCoordinator);
        console.log("On chainID: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                sunId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(sunId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperconfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 sunId,
            ,
            ,
            uint256 deployKey
        ) = helperconfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, sunId, deployKey);
    }

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployKey
    ) public {
        console.log("Adding consumer contract", raffle);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On ChainId", block.chainid);
        vm.startBroadcast(deployKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
