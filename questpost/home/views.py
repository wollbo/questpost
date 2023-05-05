import json
import logging

from django.core.exceptions import BadRequest
from django.db.models import F
from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from .decode import decode_log
from .models import Quest

# Create your views here.
logger = logging.getLogger(__name__)


def hero(request: HttpRequest) -> HttpResponse:
    return render(request, "hero.html", {})


def moralis_auth(request: HttpRequest) -> HttpResponse:
    return render(request, "base.html", {})


def profile(request: HttpRequest) -> HttpResponse:
    user = request.user.get_username()
    if user:
        quests = Quest.objects.filter(quester=user.lower()) # consider separating into active/completed quests
        questgiver = Quest.objects.filter(owner=user.lower()).distinct(
            "address"
        )
    return render(request, "profile.html", {"quests": quests, "questgiver": questgiver})


def quests(request: HttpRequest) -> HttpResponse:
    try:
        quests = Quest.objects.filter(claimable=True, active=False).distinct("address")
        context = {"valid": True, "quests": quests}
    except Exception as e:
        print(e)
    return render(request, "market.html", {"quests": context})


# view for receiving stream webhook data
def streams_reciever(request: HttpRequest): # removed render
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
            # add function to map source file to integer index
            # decoded_log["source"]
            source_index = 0
            entry = Quest(
                address=decoded_log["quest"],
                owner=decoded_log["owner"],
                target=decoded_log["target"],
                reward=decoded_log["reward"],
                duration=decoded_log["duration"],
                source=source_index,
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
                active=False, status=decoded_log["status"]
            )
        elif event == "OCRResponse":  # doesn't seem to emit anything
            pass
        elif event == "RequestSent":  # part of FunctionsClient, emits request id
            print(decoded_log)
        elif event == "RequestFulfilled":  # part of FunctionsClient, emits request id
            print(decoded_log)
