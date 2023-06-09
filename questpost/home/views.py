import json
import logging
import os

from dotenv import load_dotenv

from django.core.exceptions import BadRequest
from django.db.models import F
from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from .decode import decode_log
from .models import Quest



# Create your views here.
logger = logging.getLogger(__name__)

load_dotenv()


CONTRACT_ADDRESS = os.environ.get('CONTRACT_ADDRESS') 

def hero(request: HttpRequest) -> HttpResponse:
    return render(request, "hero.html", {})


def web3_auth(request: HttpRequest) -> HttpResponse:
    return render(request, "base.html", {})


def profile(request: HttpRequest) -> HttpResponse:
    user = request.user.get_username()
    context = {}
    if user:
        try:
            listed_quests = Quest.objects.filter(owner=user.lower(), active=False, claimable=True)
            active_quests = Quest.objects.filter(owner=user.lower(), active=True)
            finished_quests = Quest.objects.filter(owner=user.lower(), active=False, claimable=False)
            context = {"valid": True, "listed": listed_quests, "active": active_quests, "finished": finished_quests}
        except Exception as e:
            print(e)
            context = {"valid": False, "error": str(e)}
    return render(request, "profile.html", {"quests": context, "address": CONTRACT_ADDRESS})


def quests(request: HttpRequest) -> HttpResponse:
    NUM_QUEST_INDICES = 1
    context = {}
    try:
        quests = Quest.objects.filter(claimable=True, active=False).distinct("address")
        quest_indices = [str(index) for index in range(NUM_QUEST_INDICES)]  # Adjust NUM_QUEST_INDICES to match the total number of quest indices
        selected_quest_index = request.GET.get('quest_index')
        context = {"valid": True, "quests": quests, "quest_indices": quest_indices, "selected_quest_index": selected_quest_index, "address": CONTRACT_ADDRESS}
    except Exception as e:
        print(e)
        context = {"valid": False, "error": str(e), "address": CONTRACT_ADDRESS}
    return render(request, "quests.html", context)


def questlog(request: HttpRequest) -> HttpResponse:
    user = request.user.get_username()
    context = {}
    try:
        active_quests = Quest.objects.filter(quester=user.lower(), active=True)
        finished_quests = Quest.objects.filter(quester=user.lower(), active=False)
        context = {"valid": True, "active": active_quests, "finished": finished_quests}
    except Exception as e:
        print(e)
        context = {"valid": False, "error": str(e), }
    return render(request, "questlog.html", {"quests": context, "address": CONTRACT_ADDRESS})


# view for receiving stream webhook data
def streams_reciever(request: HttpRequest) -> HttpResponse: 
    logger.debug("Received request")
    print("parsing...")
    webhook_data = json.loads(request.body)
    logger.debug(f"Webhook data is {webhook_data}")
    print(webhook_data)

    if webhook_data["logs"]:
        decoded_log = decode_log(webhook_data)
        logger.debug(f"Decoded logs:  {decoded_log}")
        print(f"Writing to database... Event {decoded_log['event']}")
        streams_handler(decoded_log)

    return HttpResponse()


def streams_handler(decoded_log: dict):
    event = decoded_log["event"]
    if event not in [
        "NewQuest",
        "QuestCancelled",
        "QuestAccepted",
        "QuestFinished",
    ]:
        raise ValueError("Invalid event!")
    else:
        if event == "NewQuest":
            entry = Quest(
                address=decoded_log["quest"],
                owner=decoded_log["owner"],
                target=decoded_log["target"],
                reward=decoded_log["reward"],
                duration=decoded_log["duration"],
                questIndex=decoded_log["questIndex"],
                args=decoded_log["args"],
                active=False,
                claimable=True
            )
            entry.save()
        elif event == "QuestCancelled": # not yet implemented
            pass
        elif event == "QuestAccepted":
            Quest.objects.filter(address=decoded_log["quest"]).update(
                active=True, claimable=False, quester=decoded_log["quester"], deadline=decoded_log["deadline"]
            )  
        elif event == "QuestFinished":
            Quest.objects.filter(address=decoded_log["quest"]).update(
                claimable=False, active=False, value=decoded_log["value"], status=decoded_log["status"] # claimable=False covers "Cancelled" status
            )
        elif event == "OCRResponse":  # doesn't seem to emit anything
            pass
        elif event == "RequestSent":  # part of FunctionsClient, emits request id
            print(decoded_log)
        elif event == "RequestFulfilled":  # part of FunctionsClient, emits request id
            print(decoded_log)

        # add event "New Value: quest address + value" and update database
        # add cancel function and event
