// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./dev/functions/FunctionsClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Oracle address
// 0xeA6721aC65BCeD841B8ec3fc5fEdeA6141a0aDE4
// Artist id
// ["0qlXJWX3evE1trCvmOTPAU"]
// QuestParams
// [1, 1000, 0, 10000, ["0qlXJWX3evE1trCvmOTPAU"]]

struct QuestParams {
    uint256 target;
    uint256 reward;
    uint questIndex;
    uint256 duration;
    string[] args;
}

contract QuestPost is FunctionsClient, Ownable {
    using Functions for Functions.Request;

    uint64 subscriptionId;

    bytes32 public latestRequestId;
    bytes public latestResponse;
    bytes public latestError;
    mapping(bytes32 => address) requestIDs; // used to map back request to quest

    uint questCounter;

    constructor(address oracle, uint64 _subscriptionId) FunctionsClient(oracle) {
        subscriptionId = _subscriptionId;
    }

    event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

    mapping(address => bool) quests;

    mapping(uint => string) questDefinitions;
    mapping(uint => bytes) questSecrets;

    modifier questsOnly() {
        require(quests[msg.sender], "Sender is not a Quest");
        _;
    }

    event NewQuest(
            address indexed quest,
            address indexed owner,
            uint target,
            uint reward,
            uint duration,
            uint questIndex,
            string[] args
    );

    event QuestAccepted(
            address indexed quest,
            address indexed owner,
            uint target,
            uint questIndex,
            address indexed quester,
            uint deadline
    );

    event QuestFinished( 
            address indexed quest,
            address indexed owner,
            uint target,
            uint questIndex,
            address indexed quester,
            uint deadline,
            uint value,
            string status
    );

    function emitQuestAccepted(address _quest, address _owner, uint _target, uint _questIndex, address _quester, uint _deadline) public questsOnly {
            emit QuestAccepted(
                    _quest,
                    _owner,
                    _target,
                    _questIndex,
                    _quester,
                    _deadline
            );
    }

    function emitQuestFinished(address _quest, address _owner, uint _target, uint _questIndex, address _quester, uint _deadline, uint _value, string calldata _status) public questsOnly {
        emit QuestFinished(
                    _quest,
                    _owner,
                    _target,
                    _questIndex,
                    _quester,
                    _deadline,
                    _value,
                    _status
            );
    }


    function updateSubscriptionId(uint64 _newSubscriptionId) external onlyOwner {
        subscriptionId = _newSubscriptionId;
    }

    function registerNewQuest(string calldata _questDefinition, bytes calldata _secrets) external {
        require(msg.sender == owner());
        questDefinitions[questCounter] = _questDefinition;
        questSecrets[questCounter] = _secrets;
        questCounter += 1;
    }

    function getQuestDefinition(uint _questIndex) external view returns (string memory) {
        return questDefinitions[_questIndex];
    }

    function getQuestSecret(uint _questIndex) external view returns (bytes memory) {
        return questSecrets[_questIndex];
    }

    function newQuest(
        QuestParams calldata params
    ) external payable {
        require(msg.value == params.reward, "Incorrect reward amount");
        Quest q = new Quest{value: params.reward}(params);
        quests[address(q)] = true;
        emit NewQuest(address(q), msg.sender, params.target, params.reward, params.duration, params.questIndex, params.args);
    }

    function executeRequest(
        address _questAddress,    
        string calldata source,
        bytes calldata secrets,
        string[] calldata args,
        uint32 gasLimit
    ) public returns (bytes32) { // add questsOnly modifier
        Functions.Request memory req;
        req.initializeRequest(
            Functions.Location.Inline,
            Functions.CodeLanguage.JavaScript,
            source
        );
        req.addRemoteSecrets(secrets);

        if (args.length > 0) req.addArgs(args);
        bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit); 
        requestIDs[assignedReqID] = _questAddress;
        latestRequestId = assignedReqID; // mumbai explorer says in transaction logs "error in callback"...
        return assignedReqID;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        latestResponse = response;
        latestError = err;
        emit OCRResponse(requestId, response, err);
        Quest q = Quest(requestIDs[requestId]);
        q.receiveFulfillmentStatus(response, err);
    }
}


contract Quest {
    address payable owner;
    address payable questpost;
    address payable quester;

    //@notice The target uint number for the task, could be # followers, page ranking
    // task fulfillment is defined in external source code
    uint256 target;
    uint256 reward;

    uint256 duration;
    uint256 deadline;

    uint questIndex;
    string[] args;

    uint responseAsUint;


    bytes response;
    bytes err;

    QuestPost qp;

    enum State {
        CREATED,
        CLAIMED,
        FINISHED
    }

    State public state;

    constructor(
        QuestParams memory params
    ) payable {
        questpost = payable(msg.sender);
        qp = QuestPost(questpost);
        owner = payable(tx.origin);
        target = params.target;
        reward = params.reward;
        questIndex = params.questIndex;
        duration = params.duration;
        args = params.args;
    }

    // add collateral requirement equal to staking APR * duration * reward
    // it could be that questgiver should fund the functions subscription
    function claim() external payable {
        require(state == State.CREATED);
        quester = payable(msg.sender);
        deadline = block.timestamp + duration;
        qp.emitQuestAccepted(
            address(this),
            owner,
            target,
            questIndex,
            quester,
            deadline
        );
        state = State.CLAIMED;
    }

    // owner can cancel contract if it has not been claimed
    function cancel() external payable {
        require(msg.sender == owner, "Sender is not owner");
        require(state == State.CREATED);
        owner.transfer(address(this).balance);
        qp.emitQuestFinished(
            address(this),
            owner,
            target,
            questIndex,
            quester,
            deadline,
            0,
            "CANCELLED"
        );
        state = State.FINISHED;
    }

    function callFulfillmentStatus(uint32 gasLimit) external {
        require(msg.sender == quester);
        qp.executeRequest(
            address(this), 
            qp.getQuestDefinition(questIndex), 
            qp.getQuestSecret(questIndex), 
            args, 
            gasLimit
        );
    }

    function receiveFulfillmentStatus(
        bytes calldata _response,
        bytes calldata _err
    ) external {
        // relax this for now
        //require(msg.sender == questpost, "Sender is not Questpost!"); // callback from subscription -> questpost -> quest
        response = _response;
        err = _err;
    }

    function settle() external {
        require(state == State.CLAIMED);
        responseAsUint = abi.decode(response, (uint));
        if (block.timestamp > deadline) {
            owner.transfer(address(this).balance);
            qp.emitQuestFinished(
                    address(this),
                    owner,
                    target,
                    questIndex,
                    quester,
                    deadline,
                    responseAsUint,
                    "EXPIRED"
            );
            state = State.FINISHED;
        } else {
            require(responseAsUint > target, "Target not reached");
            quester.transfer(address(this).balance);
            qp.emitQuestFinished(
                    address(this),
                    owner,
                    target,
                    questIndex,
                    quester,
                    deadline,
                    responseAsUint,
                    "COMPLETED"
            );
            state == State.FINISHED;
        }
    }
}
