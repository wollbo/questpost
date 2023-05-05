# Create your models here.
from django.db import models


class Quest(models.Model):
    address = models.CharField(max_length=50, unique=True)
    owner = models.CharField(max_length=50)
    target = models.BigIntegerField(blank=False)
    reward = models.BigIntegerField(blank=False)
    duration = models.BigIntegerField(blank=False)
    source = models.BigIntegerField(blank=False)
    quester = models.CharField(max_length=50),
    deadline = models.BigIntegerField(),
    claimable = models.BooleanField(default=True) # if quest can be claimed
    active = models.BooleanField(default=False) # if quest is being worked on
    status = models.CharField(max_length=20)