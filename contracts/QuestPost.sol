// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./dev/functions/FunctionsClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Oracle address
// 0xeA6721aC65BCeD841B8ec3fc5fEdeA6141a0aDE4

contract QuestPost is FunctionsClient, Ownable {
    using Functions for Functions.Request;

    bytes32 public latestRequestId;
    bytes public latestResponse;
    bytes public latestError;
    mapping(bytes32 => address) requestIDs; // used to map back request to quest

    constructor(address oracle) FunctionsClient(oracle) {}

    event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

    mapping(address => bool) quests;
    uint256 ORACLE_PAYMENT = 3 * 10**17; // Payment + Subscription margin

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
            string indexed source
    );

    event QuestAccepted(
            address indexed quest,
            address indexed owner,
            uint target,
            uint reward,
            uint duration,
            string source,
            address indexed quester,
            uint deadline
    );

    event QuestFinished( // its ok to emit source, we dont have to store it completely in database
            address indexed quest,
            address indexed owner,
            uint target,
            uint reward,
            uint duration,
            string source,
            address indexed quester,
            uint deadline,
            string status
    );

    function emitQuestAccepted(address _quest, address _owner, uint _target, uint _reward, uint _duration, string calldata _source, address _quester, uint _deadline) public questsOnly {
            emit QuestAccepted(
                    _quest,
                    _owner,
                    _target,
                    _reward,
                    _duration,
                    _source,
                    _quester,
                    _deadline
            );
    }

    function emitQuestFinished(address _quest,address _owner, uint _target, uint _reward, uint _duration, string calldata _source, address _quester, uint _deadline, string calldata _status) public questsOnly {
        emit QuestFinished(
                    _quest,
                    _owner,
                    _target,
                    _reward,
                    _duration,
                    _source,
                    _quester,
                    _deadline,
                    _status
            );
    }

    function oraclePayment() public view returns (uint256) {
        return ORACLE_PAYMENT;
    }

    function updateOraclePayment(uint256 _newOraclePayment) external onlyOwner {
        ORACLE_PAYMENT = _newOraclePayment;
    }

    function swap() external payable {
        // Creates a reservation for the quest to make one call to the functions subscription
        /// @notice replace with aggregatorV3Interface for LINKETH
        uint256 LINKETH = 5 * 10**15;
        /// @notice ORACLE_PAYMENT 18 decimals
        require(msg.value >= (LINKETH * ORACLE_PAYMENT) / (10**18));
    }

    function newQuest(
        uint256 _target,
        uint256 _reward,
        string calldata _source,
        uint256 _duration // seconds
    ) external payable {
        require(msg.value == _reward, "Incorrect reward amount");
        Quest q = new Quest{value: _reward}(_target, _reward, _source, _duration);
        quests[address(q)] = true;
        emit NewQuest(address(q), msg.sender, _target, _reward, _duration, _source);
    }

    function executeRequest(
        address _questAddress,
        string calldata source,
        bytes calldata secrets,
        Functions.Location secretsLocation,
        string[] calldata args,
        uint64 subscriptionId,
        uint32 gasLimit
    ) public returns (bytes32) {
        Functions.Request memory req;
        req.initializeRequest(
            Functions.Location.Inline,
            Functions.CodeLanguage.JavaScript,
            source
        );
        if (secrets.length > 0) {
            if (secretsLocation == Functions.Location.Inline) {
                req.addInlineSecrets(secrets);
            } else {
                req.addRemoteSecrets(secrets);
            }
        }
        if (args.length > 0) req.addArgs(args);
        bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
        requestIDs[assignedReqID] = _questAddress;
        latestRequestId = assignedReqID;
        return assignedReqID;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        // add require msg.sender is oracle
        latestResponse = response;
        latestError = err;
        emit OCRResponse(requestId, response, err);
        Quest q = Quest(payable(requestIDs[requestId]));
        q.receiveFulfillmentStatus(requestId, response, err);
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

    bytes response;
    bytes err;
    string source;

    QuestPost qp;

    enum State {
        CREATED,
        CLAIMED,
        FINISHED
    }

    State public state;

    constructor(
        uint256 _target,
        uint256 _reward,
        string memory _source,
        uint256 _duration
    ) payable {
        questpost = payable(msg.sender);
        qp = QuestPost(questpost);
        owner = payable(tx.origin);
        target = _target;
        reward = _reward;
        source = _source;
        duration = _duration;
    }

    // add collateral requirement equal to staking APR * duration * reward
    // it could be that questgiver should fund the functions subscription
    function claim() external payable {
        qp.swap{value: msg.value}();
        quester = payable(msg.sender);
        deadline = block.timestamp + duration;
        qp.emitQuestAccepted(
            address(this),
            owner,
            target,
            reward,
            duration,
            source,
            quester,
            deadline
        );
        state = State.CLAIMED;
        // add keeper job to call main contract with this contract parameters
    }

    function receiveFulfillmentStatus(
        bytes32 _requestId,
        bytes calldata _response,
        bytes calldata _err
    ) external returns (bytes32) {
        require(msg.sender == questpost); // callback from subscription -> questpost -> quest
        response = _response;
        err = _err;
        return _requestId;
    }

    function settle() external {
        require(state == State.CLAIMED);
        if (block.timestamp > deadline) {
            owner.transfer(address(this).balance);
            qp.emitQuestFinished(
                    address(this),
                    owner,
                    target,
                    reward,
                    duration,
                    source,
                    quester,
                    deadline,
                    "EXPIRED"
            );
            state = State.FINISHED;
        } else {
            require(
                keccak256(abi.encodePacked(bytes("COMPLETED"))) ==
                    keccak256(abi.encodePacked(response)),
                "Task incomplete"
            );
            quester.transfer(address(this).balance);
            qp.emitQuestFinished(
                    address(this),
                    owner,
                    target,
                    reward,
                    duration,
                    source,
                    quester,
                    deadline,
                    "COMPLETED"
            );
            state == State.FINISHED;
        }
    }
}
