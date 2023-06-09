from django import template
import datetime

register = template.Library()


@register.filter
def divide_by_eight(number: float) -> float:
    return number / 10**8


@register.filter
def divide_by_eighteen(number: float) -> float:
    return number / 10**18


@register.filter
def seconds_to_days(number: float) -> float:
    return number / 86400


@register.filter
def quest_map(index):
    index = int(index)
    mapping = {
        0: "Spotify Popularity",
        1: "YouTube Subscribers",
        2: "Open PageRank"
        # Add more mappings as required
    }
    return mapping.get(index, "Unknown Quest")  # returns 'Unknown Quest' if index does not exist in mapping


@register.filter(name='args_display')
def args_display(args, questIndex):
    if not args:  # args is empty
        return "No additional information"
    if int(questIndex) == 0:
        return f"Artist ID: {args[0]}" # Adjust this based on how your args array is structured
    # Add more conditions for different questIndex values
    elif int(questIndex) == 1:
        return f"Channel: youtu.be/channel/{args[0]}"
    elif int(questIndex) == 2:
        return f"URL: https://www.{args[0]}"
    else:
        return f"Args: {args}"


@register.filter(name='short_address')
def short_address(address):
    if len(address) > 10:
        return address[:6] + '...' + address[-5:]
    else:
        return address
    

@register.filter(name='timestamp_to_date')
def timestamp_to_date(value):
    if value is not None:
        return datetime.datetime.fromtimestamp(int(value)).strftime('%Y-%m-%d %H:%M:%S')
    else:
        return None  # or some default value
    
@register.filter(name='filter_target')
def timestamp_to_date(target, questIndex):
    if int(questIndex) == 2:
        return target / 100
    return target