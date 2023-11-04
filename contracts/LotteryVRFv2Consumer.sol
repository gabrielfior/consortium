// SPDX-License-Identifier: MIT
// Consumer contract that relies on a subscription for funding.
// VRFv2Consumer.sol
// https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number

pragma solidity ^0.8.7;


import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
//import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

//contract LotteryVRFv2Consumer is VRFConsumerBaseV2, ConfirmedOwner {
contract LotteryVRFv2Consumer is VRFConsumerBaseV2 {
    address public contractOwner;
    address payable[] public players;
    uint public lotteryId;
    mapping (uint => address payable) public lotteryHistory;

    uint public ENTER_LOTTERY_FEE = 0.0000000001 ether;

    // VRFv2Consumer.sol
    // ------------------------------------------------------------------------------

    // Map requestId to request result
    mapping(uint256 => uint256) public requestIdToResult;
    
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // Sepolia coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 1 random value in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;

    event LotteryStarted(uint256 indexed requestId);
    event WinnerGenerated(uint256 indexed requestId, uint256 indexed result);

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        
    // ------------------------------------------------------------------------------
        contractOwner = msg.sender;
        lotteryId = 1;
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }

    function getWinnerByLottery(uint id) public view returns(address payable) {
        return lotteryHistory[id];
    }

    // Enter the lottery
    function enter() public payable {
        require(msg.value > ENTER_LOTTERY_FEE);
        // Address of player entering lottery
        players.push(payable(msg.sender));
    }

    // Generate a pseudo-random number for testing purpose
    // by hashing the owner's address and the timestamp of the current block
    function getPseudoRandomNumber() public view returns (uint) {
        return uint(keccak256(abi.encodePacked(contractOwner, block.timestamp)));
    }

    function pickWinner() public onlyOwner returns (uint256 requestId){
        // uint index = getPseudoRandomNumber() % players.length;
        
        // Use Chainlink VRF v2 to get true random number
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requestIdToResult[requestId] = 0;
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit LotteryStarted(requestId);
        return requestId;
        
        // TODO: further calculations pf winner's index

        // uint index = requestIdToResult[lastRequestId] % players.length;

        // // Transfer the balance of this smart contract to the winner's address
        // players[index].transfer(address(this).balance);

        // // Update the state to avoid re-entry attack
        // lotteryHistory[lotteryId] = players[index];
        // lotteryId++;
        
        // // Remove the winner
        // removePlayer(index);
    }


    function removePlayer(uint index) public {
        // Move the last element into the place to delete, and remove the last element
        players[index] = players[players.length - 1];
        players.pop();
    }

    modifier onlyOwner() {
        require(msg.sender == contractOwner);
        _;
    }

    /**
     * @notice Callback function used by VRF Coordinator to return the random number to this contract.
     *
     * @dev Some action on the contract state should be taken here, like storing the result.
     * @dev WARNING: take care to avoid having multiple VRF requests in flight if their order of arrival would result
     * in contract states with different outcomes. Otherwise miners or the VRF operator would could take advantage
     * by controlling the order.
     * @dev The VRF Coordinator will only send this function verified responses, and the parent VRFConsumerBaseV2
     * contract ensures that this method only receives randomness from the designated VRFCoordinator.
     *
     * @param requestId uint256
     * @param randomWords  uint256[] The random result returned by the oracle.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 randomNumber = randomWords[0];
        requestIdToResult[requestId] = randomNumber;
        emit WinnerGenerated(requestId, randomNumber);
    }

}