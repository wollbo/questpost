import json
import os

from django.conf import settings
from django.contrib.auth import login
from django.contrib.auth.models import User
from django.http import HttpRequest, JsonResponse
import requests
from rest_framework.decorators import api_view
from rest_framework.response import Response

API_KEY = os.environ.get("MORALIS_API_KEY", "")


def request_message(request: HttpRequest) -> JsonResponse:
    data = json.loads(request.body)

    request_object: dict[str, str | int] = {
        "domain": "questpost.xyz",
        "chainId": 80001,
        "address": data["address"],
        "statement": "Please confirm",
        "uri": "https://questpost.xyz/",
        "expirationTime": "2026-01-01T00:00:00.000Z",
        "notBefore": "2023-01-01T00:00:00.000Z",
        "timeout": 15,
    }
    x = requests.post(
        url="https://authapi.moralis.io/challenge/request/evm",
        json=request_object,
        headers={"X-API-KEY": API_KEY},
    )

    return JsonResponse(json.loads(x.text))


def verify_message(request: HttpRequest) -> JsonResponse:
    """
    Login user
    """
    data = json.loads(request.body)

    x = requests.post(
        url="https://authapi.moralis.io/challenge/verify/evm",
        json=data,
        headers={"X-API-KEY": API_KEY},
    )

    if x.status_code == 201:
        # user can authenticate
        eth_address = json.loads(x.text)["address"]
        try:
            user = User.objects.get(username=eth_address)
        except User.DoesNotExist:
            user = User(username=eth_address)
            user.is_staff = False
            user.is_superuser = False
            user.save()
        if user is not None:
            if user.is_active:
                login(request, user)
                request.session["auth_info"] = data
                request.session["verified_data"] = json.loads(x.text)
                return JsonResponse({"user": user.username})
            else:
                return JsonResponse({"error": "account disabled"})
        return JsonResponse({"error": "user is none"})
    else:
        return JsonResponse(json.loads(x.text))


def fetch_abi(request: HttpRequest) -> JsonResponse:
    """
    Loads and returns abi to front end
    """
    abi_path = os.path.join(settings.BASE_DIR, "abi.json")
    with open(abi_path) as json_file:
        data = json.load(json_file)
    return JsonResponse(data, safe=False)


def fetch_quest_abi(request: HttpRequest) -> JsonResponse:
    """
    Loads and returns quest abi to front end
    """
    quest_abi_path = os.path.join(settings.BASE_DIR, "quest_abi.json")
    with open(quest_abi_path) as json_file:
        data = json.load(json_file)
    return JsonResponse(data, safe=False)


@api_view(["POST"])
def fetch_streams(request: HttpRequest) -> Response:
    print(request)
    print(request.body)
    return Response()
