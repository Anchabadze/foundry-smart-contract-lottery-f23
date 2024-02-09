// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */

    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //////////////////
    // enterRaffle  //
    //////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER); // pretending to be the player
        // Act / Assert
        // expecting to be revert, because doesn't have enough ETH
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER); // emit the event that we expecting
        raffle.enterRaffle{value: entranceFee}(); // function call that should emit this event
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // after we done it raffle should be in calculating state
        vm.expectRevert(Raffle.RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////
    // checkUpkeep  //
    //////////////////

    function testCheckUpkeekReturnsFalseIfIthasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1); // make sure that enough time has passed
        vm.roll(block.number + 1); // make sure that enough blocks are confirmed
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded); // assert not false (which is true)
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // make sure that enough time has passed
        vm.roll(block.number + 1); // make sure that enough blocks are confirmed
        raffle.performUpkeep(""); // after we done it raffle should be in calculating state
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    ////////////////////
    // performUpkeep  //
    ////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepisTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0; // OPEN
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector, // custom error
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep(""); // expicting this transaction to fail
    }

    modifier raffleEnterAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // What if I need to test using the output of an event? (test of output if an event)

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnterAndTimePassed
    {
        // Aсt
        vm.recordLogs();
        raffle.performUpkeep(""); // this will emit the requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); // Vm.Log[] array for all logs that are emitted
        bytes32 requestId = entries[1].topics[0];
        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(requestId) > 0); // make sure that requestId was acually generated (not 0)
        assert(uint256(rState) == 1); // meaning the raffle is calculating
    }

    /////////////////////////
    // fulfillRandomWords  //
    /////////////////////////

    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnterAndTimePassed {
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }
}
