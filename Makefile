-include .env

build: 
	forge build

deploy-local:
	forge script script/DeployFundMe.s.sol:DeployFundMe --rpc-url $(LOCAL_RPC_URL) --account defaultKey --broadcast

deploy-sepolia:
	forge script script/DeployFundMe.s.sol:DeployFundMe --rpc-url $(SEPOLIA_ALCHEMY_API_URL) --account sepoliaKey --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

run-tests-on-sepolia:
	forge test --fork-url $(SEPOLIA_ALCHEMY_API_URL)

format:
	forge fmt