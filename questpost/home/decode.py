from eth_abi.abi import decode
from eth_utils import decode_hex, event_signature_to_log_topic, to_hex


def decode_log(data: dict) -> dict:
    """Decodes moralis Streams webhook data and returns event name and parameter values"""
    abi = data["abi"]
    log_data = data["logs"][0]["data"]
    topics = [d for (t, d) in data["logs"][0].items() if t.startswith("topic")]

    encoded_event_signature = topics[0]
    topics = topics[1:]
    result = {}
    for e in abi:
        if e["type"] == "event":
            event_signature = f'{e["name"]}({",".join([i["type"] for i in e["inputs"]])})'
            if to_hex(event_signature_to_log_topic(event_signature)) == encoded_event_signature:
                result["event"] = e["name"]
                inputs = [
                    {k: v for (k, v) in d.items() if k != "internalType"} for d in e["inputs"]
                ]
                break

    # Convert hex string to bytes
    log_bytes = decode_hex(log_data)

    # Split topics into topic types and data
    topic_types = [x["type"] for x in inputs if x["indexed"]]
    topic_bytes = [decode_hex(topic) if topic else b"" for topic in topics]

    # Decode topics
    decoded_topics = list(decode(topic_types, b"".join(topic_bytes)))

    # Decode data
    decoded_data = list(decode([x["type"] for x in inputs if not x["indexed"]], log_bytes))

    # Combine event name, topics and data
    for input in inputs:
        if input["indexed"]:
            result[input["name"]] = decoded_topics.pop(0)
        else:
            result[input["name"]] = decoded_data.pop(0)

    return result
