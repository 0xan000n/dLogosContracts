import {
  ethers,
  network
} from "hardhat";
import {
  deployDLogosImplementation,
  deployDLogosInstance
} from "./_helpers/deploymentFunctions";
import {
  upgradeDLogos
} from "./_helpers/upgradeFunctions";

import {
  PROXY_ADMIN_ADDRESS,
  DLOGOS_IMPLEMENTATION_ADDRESS,
  DLOGOS_INSTANCE_ADDRESS
} from "./_helpers/data";

// complete ./_helpers/data.ts with valid addresses if there are already deployed contracts
// configuration flags to select what to deploy
const DEPLOY_DLOGOS_IMPLEMENTATION = true;
const DEPLOY_DLOGOS_INSTANCE = false; // true for deploy, false for upgrade
const UPGRADE = true; // false for deploy, true for upgrade

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
  let dLogosInstance = undefined;
  let dLogosImplAddr: string;
  let dLogosInstanceAddr: string;

  // deploy DLogos implementation
  if (DEPLOY_DLOGOS_IMPLEMENTATION) {
    dLogosImpl = await deployDLogosImplementation();
  }
  dLogosImplAddr = await dLogosImpl?.getAddress() || DLOGOS_IMPLEMENTATION_ADDRESS;

  // deploy DLogos instance
  if (DEPLOY_DLOGOS_INSTANCE) {
    if (dLogosImplAddr != "") {
      dLogosInstance = await deployDLogosInstance(
        dLogosImplAddr,
        deployer.address
      );      
    } else {
      console.log("DLogos instance deployment error - Parameter missing!");
    }
  }
  dLogosInstanceAddr = await dLogosInstance?.getAddress() || DLOGOS_INSTANCE_ADDRESS;

  if (UPGRADE) {
    if (PROXY_ADMIN_ADDRESS != "" && dLogosInstanceAddr != "" && dLogosImplAddr != "") {
      await upgradeDLogos(
        PROXY_ADMIN_ADDRESS,
        dLogosInstanceAddr,
        dLogosImplAddr
      );
    } else {
      console.log("DLogos upgrade error - Parameter missing!");
    }
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
