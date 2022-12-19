include .env

default:; @forge fmt && forge build

.EXPORT_ALL_VARIABLES:
FOUNDRY_ETH_RPC_URL?=https://${NETWORK}.infura.io/v3/${INFURA_KEY}
#FOUNDRY_BLOCK_NUMBER?=15954694
ETHERSCAN_API_KEY?=${ETHERSCAN_KEY}

test:; @forge test
snapshot:; @forge snapshot
gr:; @forge test --gas-report
deploy:; @forge script script/Deploy.sol --fork-url https://${NETWORK}.infura.io/v3/${INFURA_KEY} --private-key ${PRIVATE_KEY} --broadcast --etherscan-api-key ${ETHERSCAN_KEY} --verify

.PHONY: build test snapshot gr