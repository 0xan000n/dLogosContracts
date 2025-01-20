# DLogos contracts

## Overview
This repository contains the smart contracts that implement the core logic of DLogos.

## Purpose
### DLogosOwner contract
- The centerpiece of the smart contract system, managing global constants such as rejection threshold, max duration, rejection window, team and community addresses, fee rates, and zero fee proposer addresses.
### DLogosCore contract
- A playground for logo proposers and speakers to manage the entire process, from logo creation to distribution and refunds.
### DLogosBacker contract
- The respository for backers' funds.
- Handles backers' pledges and withdrawals.

## Dependencies
- NPM: https://nodejs.org
- Hardhat: https://hardhat.org/

## Step 1. Clone the project
```bash
$ git clone https://github.com/0xan000n/dLogosContracts.git
```

## Step 2. Install dependencies
```bash
$ cd dLogosContracts
$ npm install
```

## Step 3. Configure environment variables
```bash
$ cp .env.example .env
```
Environment variables:
```dotenv
ALCHEMY_API_KEY=
ETHERSCAN_API_KEY=
DEPLOYER_PRIVATE_KEY=
```

## Step 4. Compile & Test
```bash
$ npx hardhat compile
$ npx hardhat test
```

## Step 5. Deploy
### Update deploy flags in the deployment script
```bash
$ nano scripts/deployUpgrade.ts

// deploy library flags are TRUE for deploy, TRUE or FALSE (whether to update library code) for upgrade
DEPLOY_DLOGOS_CORE_HELPER_LIBRARY: true
// deploy implementation flags are TRUE for deploy, TRUE for upgrade
DEPLOY_DLOGOS_OWNER_IMPLEMENTATION: true
DEPLOY_DLOGOS_BACKER_IMPLEMENTATION: true
DEPLOY_DLOGOS_CORE_IMPLEMENTATION: true
DEPLOY_LOGO_IMPLEMENTATION: true
// deploy instance flags are TRUE for deploy, FALSE for upgrade
DEPLOY_DLOGOS_OWNER_INSTANCE: true
DEPLOY_DLOGOS_BACKER_INSTANCE: true
DEPLOY_DLOGOS_CORE_INSTANCE: true
DEPLOY_LOGO_INSTANCE: true
// upgrade flags are FALSE for deploy, TRUE for upgrade
UPGRADE_DLOGOS_OWNER: false
UPGRADE_DLOGOS_BACKER: false
UPGRADE_DLOGOS_CORE: false
UPGRADE_LOGO: false
```
### Update deployment data with correct addresses
```bash
$ nano scripts/_helpers/data.ts

DLOGOS_ADDRESS
COMMUNITY_ADDRESS
// Matic Mumbai
TRUSTED_FORWARDER_ADDRESS
```
### Deploy DLogos implementation, DLogos proxy and ProxyAdmin
```bash
$ npx hardhat run scripts/deployUpgrade.ts --network <network-name>
```

## Step 6. Upgrade
### Update deployment data with correct addresses
```bash
$ nano scripts/_helpers/data.ts

DLOGOS_ADDRESS
COMMUNITY_ADDRESS
// Matic Mumbai
TRUSTED_FORWARDER_ADDRESS

DLOGOS_CORE_HELPER_LIBRARY_ADDRESS

DLOGOS_OWNER_PROXY_ADMIN_ADDRESS
DLOGOS_OWNER_IMPLEMENTATION_ADDRESS
DLOGOS_OWNER_INSTANCE_ADDRESS

DLOGOS_BACKER_PROXY_ADMIN_ADDRESS
DLOGOS_BACKER_IMPLEMENTATION_ADDRESS
DLOGOS_BACKER_INSTANCE_ADDRESS

DLOGOS_CORE_PROXY_ADMIN_ADDRESS
DLOGOS_CORE_IMPLEMENTATION_ADDRESS
DLOGOS_CORE_INSTANCE_ADDRESS

LOGO_PROXY_ADMIN_ADDRESS
LOGO_IMPLEMENTATION_ADDRESS
LOGO_INSTANCE_ADDRESS
```
### Update deploy flags in the deployment script
```bash
$ nano scripts/deployUpgrade.ts

// deploy library flags are TRUE for deploy, TRUE or FALSE (whether to update library code) for upgrade
DEPLOY_DLOGOS_CORE_HELPER_LIBRARY: true | false
// deploy implementation flags are TRUE for deploy, TRUE for upgrade
DEPLOY_DLOGOS_OWNER_IMPLEMENTATION: true
DEPLOY_DLOGOS_BACKER_IMPLEMENTATION: true
DEPLOY_DLOGOS_CORE_IMPLEMENTATION: true
DEPLOY_LOGO_IMPLEMENTATION: true
// deploy instance flags are TRUE for deploy, FALSE for upgrade
DEPLOY_DLOGOS_OWNER_INSTANCE: false
DEPLOY_DLOGOS_BACKER_INSTANCE: false
DEPLOY_DLOGOS_CORE_INSTANCE: false
DEPLOY_LOGO_INSTANCE: false
// upgrade flags are FALSE for deploy, TRUE for upgrade
UPGRADE_DLOGOS_OWNER: true
UPGRADE_DLOGOS_BACKER: true
UPGRADE_DLOGOS_CORE: true
UPGRADE_LOGO: true
```
### Deploy new implementations and upgrade
```bash
$ npx hardhat run scripts/deployUpgrade.ts --network <network-name>
```
