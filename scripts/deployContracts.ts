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
  let dLogosInstance = undefined;

  // factories
  const DLOGOS_F = await ethers.getContractFactory("DLogos");

  // deploy DLogos implementation
  if (DEPLOY_DLOGOS_IMPLEMENTATION) {
    dLogosImpl = await deployDLogosImplementation();
  } else if (DLOGOS_IMPLEMENTATION_ADDRESS != "") {
    dLogosImpl = DLOGOS_F.attach(DLOGOS_IMPLEMENTATION_ADDRESS);
  } else {
    console.log("DLogos implementation deployment error!");
  }

  // deploy DLogos instance
  if (DEPLOY_DLOGOS_INSTANCE) {
    dLogosInstance = await deployDLogosInstance(
      dLogosImpl!,
      deployer.address
    );
  } else if (DLOGOS_INSTANCE_ADDRESS != "") {
    dLogosInstance = DLOGOS_F.attach(DLOGOS_INSTANCE_ADDRESS);
  } else {
    console.log("DLogos instance deployment error!");
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
