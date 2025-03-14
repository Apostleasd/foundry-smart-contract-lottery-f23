// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle Contract
 * @author cy
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughEthSent();
    error Raffle_TranferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 balance,
        uint256 players,
        uint256 raffleState
    );

    /** Enums */
    enum RaffleState {
        OPEN, //0
        CALCUTATING //1
    }

    /** State Varaiables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 public immutable i_entranceFee;
    // @dev Duration of the lottery in seconds
    uint256 public immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_palyers;
    uint256 private s_lastTimeStamp;
    address private s_winner;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        if (s_raffleState == RaffleState.CALCUTATING) {
            revert Raffle_RaffleNotOpen();
        }

        s_palyers.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    //When is the winner supposed to be picked?
    /**
     * @dev This function that the Chainlink Automation node calls
     *to see if it's time to pick a winner
     *The following should be true for this to return true:
     * 1. The Time interval has passed between raffle runs
     * 2. The raffle is in the open state
     * 3. The contract has ETH (aka,palyers)
     * 4. (Implicit)The subscription is funded with LINK ETH
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool raffleIsOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPalyers = s_palyers.length > 0;
        upkeepNeeded =
            timeHasPassed &&
            raffleIsOpen &&
            hasBalance &&
            hasPalyers;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) public {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_palyers.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCUTATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_palyers.length;
        address payable winner = s_palyers[indexOfWinner];
        s_winner = winner;
        s_raffleState = RaffleState.OPEN;

        s_palyers = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TranferFailed();
        }

        emit WinnerPicked(winner);
    }

    /** Getter Function */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPalyer) public view returns (address) {
        return s_palyers[indexOfPalyer];
    }

    function getWinner() public view returns (address) {
        return s_winner;
    }

    function getLengthOfPlayers() public view returns (uint256) {
        return s_palyers.length;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
}
