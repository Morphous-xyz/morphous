from eth_abi import encode
import requests, sys, codecs, time, json

API_URL = "https://api.odos.xyz/sor/swap"

ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"


def get_quote(srcToken, dstToken, amount, side, receiver):
    time.sleep(3)

    if srcToken == ETH_ADDRESS:
        srcToken = ZERO_ADDRESS

    queryParams = {
        "chainId": 1,
        "inputTokens": [
            {
                "tokenAddress": srcToken,
                "amount": amount,
            }
        ],
        "outputTokens": [
            {
                "tokenAddress": dstToken,
                "proportion": 1,
            }
        ],
        "sourceBlacklist": [
            "Balancer V1",
            "Balancer V2 MetaStable",
            "Balancer V2 Stable",
            "Balancer V2 Weighted",
        ],
        "userAddr": receiver,
    }

    headers = {
        "accept": "application/json",
        "Content-Type": "application/json",
    }

    # Convert Python dictionary to JSON
    json_data = json.dumps(queryParams)

    price_route = requests.post(API_URL, headers=headers, data=json_data).json()

    dest_amount = price_route["outputTokens"][0]["amount"]

    data = price_route["transaction"]["data"]
    data = encode(
        ["uint256", "bytes"], [int(dest_amount), codecs.decode(data[2:], "hex_codec")]
    ).hex()
    print("0x" + str(data))


def main():
    args = sys.argv[1:]
    return get_quote(*args)


__name__ == "__main__" and main()
