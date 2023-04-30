// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./dev/functions/FunctionsClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract QuestPost is FunctionsClient, Ownable {
        using Functions for Functions.Request;
        
        bytes32 public latestRequestId;
        bytes public latestResponse;
        bytes public latestError;
        mapping (bytes32 => address) requestIDs; // used to map back request to quest

        constructor(address oracle) FunctionsClient(oracle) {}

        event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

        mapping(address => address) quests;
        uint256 ORACLE_PAYMENT = 5*10**17; // Payment + Subscription margin

        function oraclePayment() public view returns (uint256) {
                return ORACLE_PAYMENT;
        }

        function updateOraclePayment(uint256 _newOraclePayment) external onlyOwner {
                ORACLE_PAYMENT = _newOraclePayment;
        }


        function newQuest(
                uint reward,
                string calldata source, 
                uint duration
        ) external payable { // add swap function with ETH/LINK price feed
                require(msg.value == reward, "Incorrect reward amount");
                Quest q = new Quest(reward, source, duration);
                (bool sent, ) = payable(address(q)).call{value: reward}("");
                require(sent == true);
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
                req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);
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
        ) internal override { // add require msg.sender is oracle
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
        uint reward;

        uint duration;
        uint deadline;

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

        constructor (
                uint _reward,
                string memory _source,
                uint _duration
        ) {
                questpost = payable(msg.sender);
                qp = QuestPost(questpost);
                owner = payable(tx.origin);
                reward = _reward;
                source = _source;
                duration = _duration;
        }


        // add collateral requirement equal to staking APR * duration * reward
        function claim() external {
                quester = payable(msg.sender);
                deadline = block.timestamp + duration;
                state = State.CLAIMED;
                // add keeper job to call main contract with this contract parameters
        }

        function receiveFulfillmentStatus(bytes32 _requestId, bytes calldata _response, bytes calldata _err) external returns (bytes32){
                require(msg.sender == questpost); // callback from subscription -> questpost -> quest
                response = _response;
                err = _err;
                return _requestId;
        }

        function settle() external {
                require(state == State.CLAIMED);
                require( // dummy response
                        keccak256(abi.encodePacked(bytes("COMPLETED"))) ==
                                keccak256(abi.encodePacked(response)),
                        "Task incomplete"
        );
                quester.transfer(address(this).balance);
                state == State.FINISHED;
                
        }
}