import {
  ethers,
  network
} from "hardhat";
import {
  deployDLogosImplementation,
  deployDLogosInstance
} from "./_helpers/deploymentFunctions";

import {
  PROXY_ADMIN_ADDRESS,
  DLOGOS_IMPLEMENTATION_ADDRESS,
  DLOGOS_INSTANCE_ADDRESS
} from "./_helpers/data";

// configuration flags to select what to deploy
// complete ./_helpers/data.ts with valid addresses if there are already deployed contracts
const DEPLOY_DLOGOS_IMPLEMENTATION = true;
const DEPLOY_DLOGOS_INSTANCE = true;

async function main(): Promise<void> {
  console.clear();

  const [deployer] = await ethers.getSigners();
  console.log("\n\n");
  console.log("\nDEPLOYING....");
  console.log(
    "=================================================================="
  );
  console.log("Network:", network.name);
  console.log("deployerAddress :>> ", deployer.address);
  console.log("\n");

  console.log(
    "Balance before:",
    (await ethers.provider.getBalance(deployer.address)).toString()
  );

  let proxyAdmin = undefined;
  let dLogosImpl = undefined;
  let dLogosImplAddr;
  let dLogosInstance = undefined;
  let dLogosInstanceAddr;

  // deploy DLogos implementation
  if (DEPLOY_DLOGOS_IMPLEMENTATION) {
    dLogosImpl = await deployDLogosImplementation();
  }
  dLogosImplAddr = await dLogosImpl?.getAddress() || DLOGOS_IMPLEMENTATION_ADDRESS;

  console.log('dLogosImplAddr---------', dLogosImplAddr);

  // deploy DLogos instance
  if (DEPLOY_DLOGOS_INSTANCE && dLogosImplAddr != "") {
    dLogosInstance = await deployDLogosInstance(
      dLogosImplAddr,
      deployer.address
    );
  }

  console.log(
    "\n==================================================================\n"
  );
  console.log("DEPLOYMENT FINISHED....\n\n");

  console.log(
    "Balance after:",
    (await ethers.provider.getBalance(deployer.address)).toString()
  );
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
