# Create your models here.
from django.db import models


class Quest(models.Model):
    address = models.CharField(max_length=50, unique=True)
    owner = models.CharField(max_length=50)
    target = models.BigIntegerField(blank=False)
    reward = models.BigIntegerField(blank=False)
    duration = models.BigIntegerField(blank=False)
    questIndex = models.IntegerField(blank=False)
    quester = models.CharField(max_length=50)
    deadline = models.BigIntegerField(null=True)
    claimable = models.BooleanField(default=True) # if quest can be claimed
    active = models.BooleanField(default=False) # if quest is being worked on
    value = models.BigIntegerField(null=True)
    status = models.CharField(max_length=20)


    """
    address indexed quest,
    address indexed owner,
    uint target,
    uint reward,
    uint duration,
    uint questIndex,
    string[] args
    address indexed quester,
    uint deadline,
    uint value,
    string status
    """