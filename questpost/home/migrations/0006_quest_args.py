# Generated by Django 4.1.7 on 2023-06-05 06:34

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("home", "0005_remove_quest_source_quest_questindex_quest_value"),
    ]

    operations = [
        migrations.AddField(
            model_name="quest",
            name="args",
            field=models.CharField(max_length=200, null=True),
        ),
    ]
