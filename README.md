# DLogos contracts

## Dependencies
- NPM: https://nodejs.org
- Hardhat: https://hardhat.org/

## Step 1. Clone the project
```
$ git clone https://github.com/0xan000n/dLogosContracts.git
```

## Step 2. Install dependencies
```
$ cd dLogosContracts
$ npm install
```

## Step 3. Fill in environment variables
```
$ cp .env.example .env

ALCHEMY_API_KEY=
ETHERSCAN_API_KEY=
DEPLOYER_PRIVATE_KEY=
```

## Step 4. Compile & Test
```
$ npx hardhat compile
$ npx hardhat test
```

## Step 5. Deploy
### Update deploy flags in the deployment script
```
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
```
$ nano scripts/_helpers/data.ts

DLOGOS_ADDRESS
COMMUNITY_ADDRESS
// Matic Mumbai
TRUSTED_FORWARDER_ADDRESS
```
### Deploy DLogos implementation, DLogos proxy and ProxyAdmin
```
$ npx hardhat run scripts/deployUpgrade.ts --network <network-name>
```

## Step 6. Upgrade
### Update deployment data with correct addresses
```
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
```
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
```
$ npx hardhat run scripts/deployUpgrade.ts --network <network-name>
```
