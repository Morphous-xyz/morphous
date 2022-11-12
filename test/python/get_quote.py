import requests, sys, codecs
from eth_abi import encode

API_URL = "https://apiv5.paraswap.io"

def get_quote(
    srcToken, dstToken, srcDecimals, dstDecimals, amount, side, network, receiver
):
    queryParams = {
        "srcToken": srcToken,
        "destToken": dstToken,
        "amount": amount,
        "side": side,
        "network": network,
    }

    url = API_URL + "/prices/"
    price_route = requests.get(url, params=queryParams).json()

    dest_amount = price_route["priceRoute"]["destAmount"] if side == "SELL" else price_route["priceRoute"]["srcAmount"]

    queryParams = {
        "priceRoute": price_route["priceRoute"],
        "srcToken": srcToken,
        "destToken": dstToken,
        "srcAmount": amount if side == "SELL" else dest_amount,
        "destAmount": dest_amount if side == "SELL" else amount,
        "userAddress": receiver,
    }

    url = API_URL + "/transactions/1/?ignoreChecks=true"
    response = requests.post(
        url, json=queryParams
    ).json()

    data = response["data"]
    data = encode(["uint256", "bytes"], [int(dest_amount), codecs.decode(data[2:], "hex_codec")]).hex()
    print("0x" + str(data))

def main():
    args = sys.argv[1:]
    return get_quote(*args)

__name__ == "__main__" and main()