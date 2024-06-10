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

const DEPLOY_DLOGOS_IMPLEMENTATION = true;
const DEPLOY_DLOGOS_INSTANCE = true;
const UPGRADE = false;
```
### Deploy DLogos implementation, DLogos proxy and ProxyAdmin
```
$ npx hardhat run scripts/deployUpgrade.ts --network sepolia
```

## Step 6. Verify
### DLogos implementation
```
$ npx hardhat verify implementation_contract_address --network sepolia
```
### TransparentUpgradeableProxy
#### Update constructor arguments
```
$ nano scripts/proxArgs.ts

IMPLEMENTATION_ADDRESS
INITIAL_OWNER_ADDRESS
INIT_DATA
```
#### Verify
```
$ npx hardhat verify proxy_contract_address --constructor-args scripts/proxyArgs.ts --network sepolia
```

## Step 7. Upgrade
### Update deployment data with correct addresses
```
$ nano scripts/_helpers/data.ts

PROXY_ADMIN_ADDRESS
DLOGOS_INSTANCE_ADDRESS
```
### Update deploy flags in the deployment script
```
$ nano scripts/deployUpgrade.ts

const DEPLOY_DLOGOS_IMPLEMENTATION = true;
const DEPLOY_DLOGOS_INSTANCE = false;
const UPGRADE = true;
```
### Deploy a new implementation and upgrade
```
$ npx hardhat run scripts/deployUpgrade.ts --network sepolia
```
### Verify a new implementation
```
$ npx hardhat verify implementation_contract_address --network sepolia
```
