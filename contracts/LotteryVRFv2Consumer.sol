// SPDX-License-Identifier: MIT
// Consumer contract that relies on a subscription for funding.
// VRFv2Consumer.sol
// https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number

pragma solidity ^0.8.7;


import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract LotteryVRFv2Consumer is VRFConsumerBaseV2, ConfirmedOwner {

    address public contractOwner;
    address payable[] public players;
    uint public lotteryId;
    mapping (uint => address payable) public lotteryHistory;

    uint public ENTER_LOTTERY_FEE = 0.01 ether;

    // VRFv2Consumer.sol
    // ------------------------------------------------------------------------------
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

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

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 2;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(
        uint64 subscriptionId
    )
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
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

    function pickWinner() public onlyByOwner {
        // uint index = getPseudoRandomNumber() % players.length;
        
        // Use Chainlink VRF v2 to get true random number
        lastRequestId = this.requestRandomWords();
        bool fulfilled;
        uint[] memory randomNumbers;
        (fulfilled, randomNumbers) = this.getRequestStatus(lastRequestId);
        uint index = randomNumbers[0] % players.length;

        // Transfer the balance of this smart contract to the winner's address
        players[index].transfer(address(this).balance);

        // Update the state to avoid re-entry attack
        lotteryHistory[lotteryId] = players[index];
        lotteryId++;
        
        // Remove the winner
        removePlayer(index);
    }


    function removePlayer(uint index) public {
        // Move the last element into the place to delete, and remove the last element
        players[index] = players[players.length - 1];
        players.pop();
    }

    modifier onlyByOwner() {
        require(msg.sender == contractOwner);
        _;
    }
    

    // VRFv2Consumer.sol
    // ------------------------------------------------------------------------------
    // Assumes the subscription is funded sufficiently.
    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

}