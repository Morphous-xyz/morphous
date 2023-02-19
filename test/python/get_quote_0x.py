import requests, sys, codecs
from eth_abi import encode

API_URL = "https://api.0x.org/swap/v1"

def get_quote(
    srcToken, dstToken, amount, side, network, receiver
):
    queryParams = {
        "sellToken": srcToken,
        "buyToken": dstToken,
        "slippagePercentage": 0.03,
        "excludedSources": "Balancer"
    }

    if(side == "SELL"):
        queryParams["sellAmount"] = amount
    elif(side=="BUY"):
        queryParams["buyAmount"]= amount

    url = API_URL + "/quote"
    price_route = requests.get(url, params=queryParams).json()

    dest_amount = price_route["buyAmount"] if side == "SELL" else price_route["sellAmount"]


    data = price_route["data"]
    data = encode(
        ["uint256", "bytes"], [int(dest_amount), codecs.decode(data[2:], "hex_codec")]
    ).hex()
    print("0x" + str(data))


def main():
    args = sys.argv[1:]
    return get_quote(*args)


__name__ == "__main__" and main()
