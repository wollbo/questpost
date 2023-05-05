# Create your models here.
from django.db import models


class Wallet(models.Model):
    address = models.CharField(max_length=50)
    balance = models.FloatField()
