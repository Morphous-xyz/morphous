set dotenv-load := true


# Default command
default:
  @just --list

install:
	foundryup && forge install 

# Formatting all contracts
format: 
    forge fmt

# Compiling contracts 
build: format
	forge build

# Run all tests
test: 
	forge test --fork-url https://$NETWORK.infura.io/v3/$INFURA_KEY

# Testing specific contract (regex contract name)
test-c CONTRACT_NAME :
	forge test --match-contract {{CONTRACT_NAME}}  --fork-url https://$NETWORK.infura.io/v3/$INFURA_KEY

# Testing specific function (regex function name)
test-f FUNCTION :
	forge test --match-test {{FUNCTION}} --fork-url https://$NETWORK.infura.io/v3/$INFURA_KEY

# Removing all generated files
clean:
	forge clean && rm -rf node_modules