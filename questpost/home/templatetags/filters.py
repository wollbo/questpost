from django import template

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