set dotenv-load := true

# Default command
default: format
	forge build

# Install dependencies
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
	forge test --fork-url $RPC_URL_MAINNET

# Testing specific contract (regex contract name)
test-c CONTRACT_NAME :
	forge test --match-contract {{CONTRACT_NAME}}  --fork-url $RPC_URL_MAINNET

# Testing specific function (regex function name)
test-f FUNCTION :
	forge test --match-test {{FUNCTION}} --fork-url $RPC_URL_MAINNET

# Run coverage
coverage :
	forge coverage --fork-url $RPC_URL_MAINNET

# Coverage and write to an html (in coverage folder) 
coverage-w :
	forge coverage --report lcov --fork-url $RPC_URL_MAINNET
	lcov --remove ./lcov.info -o ./lcov.info.pruned 'test/*' 'script/*'
	genhtml ./lcov.info.pruned -o report --branch-coverage --output-dir ./coverage
	rm ./lcov.info*

#  Analyze a contract with Mythril (Docker must be opened)
mythril PATH CONTRACT_NAME :
	forge flatten {{PATH}}{{CONTRACT_NAME}} --output temp/{{CONTRACT_NAME}}
	cd temp/ && docker run -v $(pwd):/temp mythril/myth analyze /temp/{{CONTRACT_NAME}}
	cd temp/ && rm {{CONTRACT_NAME}}
	cd ../

# Deploy Morphous, Neo and FL
deploy-core : 
	forge script script/DeployCore.s.sol --fork-url $RPC_URL_MAINNET  --broadcast

# Deploy modules and logger + adding modules to Morphous
deploy-modules :
	forge script script/DeployModules.s.sol --fork-url $RPC_URL_MAINNET  --broadcast

# Removing all generated files
clean:
	forge clean && rm -rf temp && rm -rf coverage 