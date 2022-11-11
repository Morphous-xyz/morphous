include .env

.EXPORT_ALL_VARIABLES:
FOUNDRY_ETH_RPC_URL?=https://${NETWORK}.infura.io/v3/${INFURA_KEY}
ETHERSCAN_API_KEY?=${ETHERSCAN_KEY}

default:; @forge fmt && forge build
test:; @forge test --no-match-test  testParaswap 
test-paraswap:; @forge test --match-test  testParaswap 

.PHONY: build test snapshot quote