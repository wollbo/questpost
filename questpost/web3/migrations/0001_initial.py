# Generated by Django 4.1.7 on 2023-05-08 10:58

from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Wallet",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                ("address", models.CharField(max_length=50)),
                ("balance", models.FloatField()),
            ],
        ),
    ]
