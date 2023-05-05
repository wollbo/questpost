from django.urls import path

from . import views

urlpatterns = [
    path("", views.hero, name="hero"),
    path("login", views.moralis_auth, name="moralis_auth"),
    path("profile/", views.profile, name="profile"), # view my created quests and accepted quests
    path("streams", views.streams_reciever, name="streams_receiver"),
    path("quests/", views.quests, name="quests"),
]
