import requests, sys
from eth_abi import encode_single


API_URL = "https://apiv5.paraswap.io"


def get_quote(
    srcToken, dstToken, srcDecimals, dstDecimals, amount, side, network, receiver
):
    queryParams = {
        "srcToken": srcToken,
        "destToken": dstToken,
        "srcDecimals": srcDecimals,
        "destDecimals": dstDecimals,
        "amount": amount,
        "side": side,
        "network": network,
    }

    url = API_URL + "/prices/"
    price_route = requests.get(url, params=queryParams).json()


    dest_amount = price_route["priceRoute"]["destAmount"]

    queryParams = {
        "priceRoute": price_route["priceRoute"],
        "srcToken": srcToken,
        "destToken": dstToken,
        "srcAmount": amount,
        "destAmount": dest_amount,
        "userAddress": receiver,
    }

    url = API_URL + "/transactions/1/?ignoreChecks=true"
    response = requests.post(
        url, json=queryParams
    ).json()

    dest_amount = encode_single("uint256", int(dest_amount))
    data = response["data"]
    print(
        "0x"
        + dest_amount.hex()
        + "000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e4"
        + data[2:]
    )


def main():
    args = sys.argv[1:]
    return get_quote(*args)


__name__ == "__main__" and main()