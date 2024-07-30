# Makefile for Hardhat Deployment

# Define variables for the commands
HH=hh
TS_NODE=npx ts-node
DEPLOY_QP_SCRIPT=scripts/deploy/deployQp.ts
DEPLOY_MULTISWAP_SCRIPT=scripts/deploy/multiswap/multiswap.ts
POST_DEPLOY_CONFIG_SCRIPT=scripts/deploy/multiswap/postDeployConfig.ts
MINE_QP_SCRIPT=scripts/mineQp.ts

# Define USDC addresses for non-localhost deployments
arbitrumOneUSDC=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
baseUSDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

# Define a target for deploying deployQp.ts
deploy-qp:
	@$(HH) run $(DEPLOY_QP_SCRIPT) --network $(network) | tee qp_output_$(network).txt

# Define a target for deploying multiswap.ts
deploy-multiswap:
	@portalAddress=$(shell grep -Eo 'Portal:\s+0x[a-fA-F0-9]+' qp_output_$(network).txt | awk '{print $$2}') && \
	 feeTokenAddress=$(shell grep -Eo 'FeeToken:\s+0x[a-fA-F0-9]+' qp_output_$(network).txt | awk '{print $$2}') && \
	 PORTAL_ADDRESS=$$portalAddress \
	 FEE_TOKEN_ADDRESS=$$feeTokenAddress \
	 $(HH) run $(DEPLOY_MULTISWAP_SCRIPT) --network $(network) | tee multiswap_output_$(network).txt

# Define a target for running postDeployConfig.ts on arbitrumOne
post-deploy-config-arbitrumOne:
	@fiberRouterAddress=$(shell grep -Eo 'FiberRouter:\s+0x[a-fA-F0-9]+' multiswap_output_arbitrumOne.txt | awk '{print $$2}') && \
	 otherFiberRouterAddress=$(shell grep -Eo 'FiberRouter:\s+0x[a-fA-F0-9]+' multiswap_output_base.txt | awk '{print $$2}') && \
	 otherChainId=$(shell grep -Eo 'Chain ID:\s+[0-9]+' qp_output_base.txt | awk '{print $$3}') && \
	 FIBER_ROUTER_ADDRESS=$$fiberRouterAddress \
	 OTHER_FIBER_ROUTER_ADDRESS=$$otherFiberRouterAddress \
	 THIS_USDC=$(arbitrumOneUSDC) \
	 OTHER_USDC=$(baseUSDC) \
	 OTHER_CHAIN_ID=$$otherChainId \
	 $(HH) run $(POST_DEPLOY_CONFIG_SCRIPT) --network arbitrumOne

# Define a target for running postDeployConfig.ts on base
post-deploy-config-base:
	@fiberRouterAddress=$(shell grep -Eo 'FiberRouter:\s+0x[a-fA-F0-9]+' multiswap_output_base.txt | awk '{print $$2}') && \
	 otherFiberRouterAddress=$(shell grep -Eo 'FiberRouter:\s+0x[a-fA-F0-9]+' multiswap_output_arbitrumOne.txt | awk '{print $$2}') && \
	 otherChainId=$(shell grep -Eo 'Chain ID:\s+[0-9]+' qp_output_arbitrumOne.txt | awk '{print $$3}') && \
	 FIBER_ROUTER_ADDRESS=$$fiberRouterAddress \
	 OTHER_FIBER_ROUTER_ADDRESS=$$otherFiberRouterAddress \
	 THIS_USDC=$(baseUSDC) \
	 OTHER_USDC=$(arbitrumOneUSDC) \
	 OTHER_CHAIN_ID=$$otherChainId \
	 $(HH) run $(POST_DEPLOY_CONFIG_SCRIPT) --network base

# Define a target for running postDeployConfig.ts on localhost1
post-deploy-config-localhost1:
	@fiberRouterAddress=$(shell grep -Eo 'FiberRouter:\s+0x[a-fA-F0-9]+' multiswap_output_localhost1.txt | awk '{print $$2}') && \
	 otherFiberRouterAddress=$(shell grep -Eo 'FiberRouter:\s+0x[a-fA-F0-9]+' multiswap_output_localhost2.txt | awk '{print $$2}') && \
	 otherChainId=$(shell grep -Eo 'Chain ID:\s+[0-9]+' qp_output_localhost2.txt | awk '{print $$3}') && \
	 usdcAddress=$(shell grep -Eo 'USDC:\s+0x[a-fA-F0-9]+' multiswap_output_localhost1.txt | awk '{print $$2}') && \
	 otherUsdcAddress=$(shell grep -Eo 'USDC:\s+0x[a-fA-F0-9]+' multiswap_output_localhost2.txt | awk '{print $$2}') && \
	 FIBER_ROUTER_ADDRESS=$$fiberRouterAddress \
	 OTHER_FIBER_ROUTER_ADDRESS=$$otherFiberRouterAddress \
	 THIS_USDC=$$usdcAddress \
	 OTHER_USDC=$$otherUsdcAddress \
	 OTHER_CHAIN_ID=$$otherChainId \
	 $(HH) run $(POST_DEPLOY_CONFIG_SCRIPT) --network localhost1

# Define a target for running postDeployConfig.ts on localhost2
post-deploy-config-localhost2:
	@fiberRouterAddress=$(shell grep -Eo 'FiberRouter:\s+0x[a-fA-F0-9]+' multiswap_output_localhost2.txt | awk '{print $$2}') && \
	 otherFiberRouterAddress=$(shell grep -Eo 'FiberRouter:\s+0x[a-fA-F0-9]+' multiswap_output_localhost1.txt | awk '{print $$2}') && \
	 otherChainId=$(shell grep -Eo 'Chain ID:\s+[0-9]+' qp_output_localhost1.txt | awk '{print $$3}') && \
	 usdcAddress=$(shell grep -Eo 'USDC:\s+0x[a-fA-F0-9]+' multiswap_output_localhost2.txt | awk '{print $$2}') && \
	 otherUsdcAddress=$(shell grep -Eo 'USDC:\s+0x[a-fA-F0-9]+' multiswap_output_localhost1.txt | awk '{print $$2}') && \
	 FIBER_ROUTER_ADDRESS=$$fiberRouterAddress \
	 OTHER_FIBER_ROUTER_ADDRESS=$$otherFiberRouterAddress \
	 THIS_USDC=$$usdcAddress \
	 OTHER_USDC=$$otherUsdcAddress \
	 OTHER_CHAIN_ID=$$otherChainId \
	 $(HH) run $(POST_DEPLOY_CONFIG_SCRIPT) --network localhost2

mine-qp:
	@fromGateway=$(shell grep -Eo 'Gate:\s+0x[a-fA-F0-9]+' qp_output_$(fromNetwork).txt | awk '{print $$2}') && \
	 toGateway=$(shell grep -Eo 'Gate:\s+0x[a-fA-F0-9]+' qp_output_$(toNetwork).txt | awk '{print $$2}') && \
	 $(TS_NODE) $(MINE_QP_SCRIPT) $(fromNetwork):$$fromGateway $(toNetwork):$$toGateway

mine-qp-local:
	@$(MAKE) mine-qp fromNetwork=localhost1 toNetwork=localhost2

mine-qp-live:
	@$(MAKE) mine-qp fromNetwork=arbitrumOne toNetwork=base

# Define a target for full deployment including context generation and setup
deploy-all: deploy-qp-arbitrumOne deploy-qp-base deploy-multiswap-arbitrumOne deploy-multiswap-base post-deploy-config-arbitrumOne post-deploy-config-base

# Define a target for full deployment on local networks
deploy-all-local: deploy-qp-localhost1 deploy-qp-localhost2 deploy-multiswap-localhost1 deploy-multiswap-localhost2 post-deploy-config-localhost1 post-deploy-config-localhost2

# Define individual targets for each network
deploy-qp-arbitrumOne:
	@$(MAKE) deploy-qp network=arbitrumOne

deploy-qp-base:
	@$(MAKE) deploy-qp network=base

deploy-qp-localhost1:
	@$(MAKE) deploy-qp network=localhost1

deploy-qp-localhost2:
	@$(MAKE) deploy-qp network=localhost2

deploy-multiswap-arbitrumOne:
	@$(MAKE) deploy-multiswap network=arbitrumOne

deploy-multiswap-base:
	@$(MAKE) deploy-multiswap network=base

deploy-multiswap-localhost1:
	@$(MAKE) deploy-multiswap network=localhost1

deploy-multiswap-localhost2:
	@$(MAKE) deploy-multiswap network=localhost2

# Define a help target to display available commands
help:
	@echo "Available commands:"
	@echo "  make deploy-qp-arbitrumOne       - Deploy deployQp.ts to Arbitrum One"
	@echo "  make deploy-qp-base              - Deploy deployQp.ts to Base"
	@echo "  make deploy-qp-localhost1        - Deploy deployQp.ts to Localhost1"
	@echo "  make deploy-qp-localhost2        - Deploy deployQp.ts to Localhost2"
	@echo "  make deploy-multiswap-arbitrumOne - Deploy multiswap.ts to Arbitrum One"
	@echo "  make deploy-multiswap-base       - Deploy multiswap.ts to Base"
	@echo "  make deploy-multiswap-localhost1 - Deploy multiswap.ts to Localhost1"
	@echo "  make deploy-multiswap-localhost2 - Deploy multiswap.ts to Localhost2"
	@echo "  make post-deploy-config-arbitrumOne - Run post deployment config on Arbitrum One"
	@echo "  make post-deploy-config-base     - Run post deployment config on Base"
	@echo "  make post-deploy-config-localhost1 - Run post deployment config on Localhost1"
	@echo "  make post-deploy-config-localhost2 - Run post deployment config on Localhost2"
	@echo "  make mine-qp-local               - Run mineQp.ts from localhost1 to localhost2"
	@echo "  make mine-qp-live                - Run mineQp.ts from arbitrumOne to base"
	@echo "  make deploy-all                  - Deploy all scripts and perform setup on all networks"
	@echo "  make deploy-all-local            - Deploy all scripts and perform setup on local networks"
	@echo "  make help                        - Display this help message"

.PHONY: deploy-qp deploy-multiswap post-deploy-config-arbitrumOne post-deploy-config-base post-deploy-config-localhost1 post-deploy-config-localhost2 mine-qp mine-qp-local mine-qp-live deploy-all deploy-all-local help
