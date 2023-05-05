from django.urls import path

from . import views

urlpatterns = [
    path("request_message", views.request_message, name="request_message"),
    path("verify_message", views.verify_message, name="verify_message"),
    path("fetch_abi", views.fetch_abi, name="fetch_abi"),
    path("fetch_quest_abi", views.fetch_quest_abi, name="fetch_quest_abi"),
    path("streams", views.fetch_streams, name="streams"),
]
