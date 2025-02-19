import {
  ethers,
  network,
} from "hardhat";
import _ from "lodash";
import {
  deployDLogosCoreHelperLibrary,
  deployDLogosOwnerImplementation,
  deployDLogosOwnerInstance,
  deployDLogosBackerImplementation,
  deployDLogosBackerInstance,
  deployDLogosCoreImplementation,
  deployDLogosCoreInstance,
  deployLogoImplementation,
  deployLogoInstance,
} from "./_helpers/deploymentFunctions";
import {
  upgrade,
} from "./_helpers/upgradeFunctions";

import data from "./_helpers/data";

// //-----------------configuration flags to select what to deploy-----------------//
// // deploy library flags are TRUE for deploy, TRUE or FALSE (whether to update library code) for upgrade
// const DEPLOY_DLOGOS_CORE_HELPER_LIBRARY = true;
// // deploy implementation flags are TRUE for deploy, TRUE for upgrade
// const DEPLOY_DLOGOS_OWNER_IMPLEMENTATION = true;
// const DEPLOY_DLOGOS_BACKER_IMPLEMENTATION = true;
// const DEPLOY_DLOGOS_CORE_IMPLEMENTATION = true;
// const DEPLOY_LOGO_IMPLEMENTATION = true;
// // deploy instance flags are TRUE for deploy, FALSE for upgrade
// const DEPLOY_DLOGOS_OWNER_INSTANCE = true;
// const DEPLOY_DLOGOS_BACKER_INSTANCE = true;
// const DEPLOY_DLOGOS_CORE_INSTANCE = true;
// const DEPLOY_LOGO_INSTANCE = true;
// // upgrade flags are FALSE for deploy, TRUE for upgrade
// const UPGRADE_DLOGOS_OWNER = false;
// const UPGRADE_DLOGOS_BACKER = false;
// const UPGRADE_DLOGOS_CORE = false;
// const UPGRADE_LOGO = false;



// temporary flags to resume mainnet deployment
const DEPLOY_DLOGOS_CORE_HELPER_LIBRARY = false;
const DEPLOY_DLOGOS_OWNER_IMPLEMENTATION = false;
const DEPLOY_DLOGOS_BACKER_IMPLEMENTATION = false;
const DEPLOY_DLOGOS_CORE_IMPLEMENTATION = false;
const DEPLOY_LOGO_IMPLEMENTATION = true;
const DEPLOY_DLOGOS_OWNER_INSTANCE = false;
const DEPLOY_DLOGOS_BACKER_INSTANCE = false;
const DEPLOY_DLOGOS_CORE_INSTANCE = true;
const DEPLOY_LOGO_INSTANCE = true;
const UPGRADE_DLOGOS_OWNER = false;
const UPGRADE_DLOGOS_BACKER = false;
const UPGRADE_DLOGOS_CORE = false;
const UPGRADE_LOGO = false;

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

  const prefix = _.toUpper(_.snakeCase(network.name));

  const DLOGOS_ADDRESS = data[`${prefix}_DLOGOS_ADDRESS` as keyof typeof data];
  const COMMUNITY_ADDRESS = data[`${prefix}_COMMUNITY_ADDRESS` as keyof typeof data];
  const TRUSTED_FORWARDER_ADDRESS = data[`${prefix}_TRUSTED_FORWARDER_ADDRESS` as keyof typeof data];
  const DLOGOS_CORE_HELPER_LIBRARY_ADDRESS = data[`${prefix}_DLOGOS_CORE_HELPER_LIBRARY_ADDRESS` as keyof typeof data];
  const DLOGOS_OWNER_PROXY_ADMIN_ADDRESS = data[`${prefix}_DLOGOS_OWNER_PROXY_ADMIN_ADDRESS` as keyof typeof data];
  const DLOGOS_OWNER_IMPLEMENTATION_ADDRESS = data[`${prefix}_DLOGOS_OWNER_IMPLEMENTATION_ADDRESS` as keyof typeof data];
  const DLOGOS_OWNER_INSTANCE_ADDRESS = data[`${prefix}_DLOGOS_OWNER_INSTANCE_ADDRESS` as keyof typeof data];
  const DLOGOS_BACKER_PROXY_ADMIN_ADDRESS = data[`${prefix}_DLOGOS_BACKER_PROXY_ADMIN_ADDRESS` as keyof typeof data];
  const DLOGOS_BACKER_IMPLEMENTATION_ADDRESS = data[`${prefix}_DLOGOS_BACKER_IMPLEMENTATION_ADDRESS` as keyof typeof data];
  const DLOGOS_BACKER_INSTANCE_ADDRESS = data[`${prefix}_DLOGOS_BACKER_INSTANCE_ADDRESS` as keyof typeof data];
  const DLOGOS_CORE_PROXY_ADMIN_ADDRESS = data[`${prefix}_DLOGOS_CORE_PROXY_ADMIN_ADDRESS` as keyof typeof data];
  const DLOGOS_CORE_IMPLEMENTATION_ADDRESS = data[`${prefix}_DLOGOS_CORE_IMPLEMENTATION_ADDRESS` as keyof typeof data];
  const DLOGOS_CORE_INSTANCE_ADDRESS = data[`${prefix}_DLOGOS_CORE_INSTANCE_ADDRESS` as keyof typeof data];
  const LOGO_PROXY_ADMIN_ADDRESS = data[`${prefix}_LOGO_PROXY_ADMIN_ADDRESS` as keyof typeof data];
  const LOGO_IMPLEMENTATION_ADDRESS = data[`${prefix}_LOGO_IMPLEMENTATION_ADDRESS` as keyof typeof data];
  const LOGO_INSTANCE_ADDRESS = data[`${prefix}_LOGO_INSTANCE_ADDRESS` as keyof typeof data];

  // DLogosCoreHelper
  let dLogosCoreHelper = undefined;
  let dLogosCoreHelperAddr: string;
  // DLogosOwner
  let dLogosOwnerProxyAdmin = undefined;
  let dLogosOwnerImpl = undefined;
  let dLogosOwnerInstance = undefined;
  let dLogosOwnerProxyAdminAddr: string;
  let dLogosOwnerImplAddr: string;
  let dLogosOwnerInstanceAddr: string;
  // DLogosBacker
  let dLogosBackerProxyAdmin = undefined;
  let dLogosBackerImpl = undefined;
  let dLogosBackerInstance = undefined;
  let dLogosBackerProxyAdminAddr: string;
  let dLogosBackerImplAddr: string;
  let dLogosBackerInstanceAddr: string;
  // DLogosCore
  let dLogosCoreProxyAdmin = undefined;
  let dLogosCoreImpl = undefined;
  let dLogosCoreInstance = undefined;
  let dLogosCoreProxyAdminAddr: string;
  let dLogosCoreImplAddr: string;
  let dLogosCoreInstanceAddr: string;
  // Logo
  let logoProxyAdmin = undefined;
  let logoImpl = undefined;
  let logoInstance = undefined;
  let logoProxyAdminAddr: string;
  let logoImplAddr: string;
  let logoInstanceAddr: string;

  // deploy DLogosOwner implementation
  if (DEPLOY_DLOGOS_OWNER_IMPLEMENTATION) {
    dLogosOwnerImpl = await deployDLogosOwnerImplementation();
  }
  dLogosOwnerImplAddr = await dLogosOwnerImpl?.getAddress() || DLOGOS_OWNER_IMPLEMENTATION_ADDRESS;
  // deploy DLogosOwner instance
  if (DEPLOY_DLOGOS_OWNER_INSTANCE) {
    if (dLogosOwnerImplAddr != "" && DLOGOS_ADDRESS != "" && COMMUNITY_ADDRESS != "") {
      const result = await deployDLogosOwnerInstance(
        dLogosOwnerImplAddr,
        deployer.address,
        DLOGOS_ADDRESS,
        COMMUNITY_ADDRESS,
      );
      dLogosOwnerProxyAdmin = result.dLogosOwnerProxyAdmin;
      dLogosOwnerInstance = result.dLogosOwnerInstance;
    } else {
      console.log("DLogosOwner instance deployment error - Parameter missing!");
    }
  }
  dLogosOwnerInstanceAddr = await dLogosOwnerInstance?.getAddress() || DLOGOS_OWNER_INSTANCE_ADDRESS;
  dLogosOwnerProxyAdminAddr = await dLogosOwnerProxyAdmin?.getAddress() || DLOGOS_OWNER_PROXY_ADMIN_ADDRESS;

  // deploy DLogosBacker implementation
  if (DEPLOY_DLOGOS_BACKER_IMPLEMENTATION) {
    dLogosBackerImpl = await deployDLogosBackerImplementation();
  }
  dLogosBackerImplAddr = await dLogosBackerImpl?.getAddress() || DLOGOS_BACKER_IMPLEMENTATION_ADDRESS;
  // deploy DLogosBacker instance
  if (DEPLOY_DLOGOS_BACKER_INSTANCE) {
    if (dLogosBackerImplAddr != "" && TRUSTED_FORWARDER_ADDRESS != "" && dLogosOwnerInstanceAddr != "") {
      const result = await deployDLogosBackerInstance(
        dLogosBackerImplAddr,
        deployer.address,
        TRUSTED_FORWARDER_ADDRESS,
        dLogosOwnerInstanceAddr,
      );
      dLogosBackerProxyAdmin = result.dLogosBackerProxyAdmin;
      dLogosBackerInstance = result.dLogosBackerInstance;
    } else {
      console.log("DLogosBacker instance deployment error - Parameter missing!");
    }
  }
  dLogosBackerInstanceAddr = await dLogosBackerInstance?.getAddress() || DLOGOS_BACKER_INSTANCE_ADDRESS;
  dLogosBackerProxyAdminAddr = await dLogosBackerProxyAdmin?.getAddress() || DLOGOS_BACKER_PROXY_ADMIN_ADDRESS;

  // deploy DLogosCoreHelper library
  if (DEPLOY_DLOGOS_CORE_HELPER_LIBRARY) {
    dLogosCoreHelper = await deployDLogosCoreHelperLibrary();
  }
  dLogosCoreHelperAddr = await dLogosCoreHelper?.getAddress() || DLOGOS_CORE_HELPER_LIBRARY_ADDRESS;

  // deploy DLogosCore implementation
  if (DEPLOY_DLOGOS_CORE_IMPLEMENTATION) {
    dLogosCoreImpl = await deployDLogosCoreImplementation(dLogosCoreHelperAddr);
  }
  dLogosCoreImplAddr = await dLogosCoreImpl?.getAddress() || DLOGOS_CORE_IMPLEMENTATION_ADDRESS;
  // deploy DLogosCore instance
  if (DEPLOY_DLOGOS_CORE_INSTANCE) {
    if (dLogosCoreImplAddr != "" && dLogosOwnerInstanceAddr != "") {
      const result = await deployDLogosCoreInstance(
        dLogosCoreHelperAddr,
        dLogosCoreImplAddr,
        deployer.address,
        dLogosOwnerInstanceAddr,
      );
      dLogosCoreProxyAdmin = result.dLogosCoreProxyAdmin;
      dLogosCoreInstance = result.dLogosCoreInstance;
    } else {
      console.log("DLogosCore instance deployment error - Parameter missing!");
    }
  }
  dLogosCoreInstanceAddr = await dLogosCoreInstance?.getAddress() || DLOGOS_CORE_INSTANCE_ADDRESS;
  dLogosCoreProxyAdminAddr = await dLogosCoreProxyAdmin?.getAddress() || DLOGOS_CORE_PROXY_ADMIN_ADDRESS;

  // deploy Logo implementation
  if (DEPLOY_LOGO_IMPLEMENTATION) {
    logoImpl = await deployLogoImplementation();
  }
  logoImplAddr = await logoImpl?.getAddress() || LOGO_IMPLEMENTATION_ADDRESS;
  // deploy Logo instance
  if (DEPLOY_LOGO_INSTANCE) {
    if (logoImplAddr != "" && dLogosOwnerInstanceAddr != "") {
      const result = await deployLogoInstance(
        logoImplAddr,
        deployer.address,
        dLogosOwnerInstanceAddr,
      );
      logoProxyAdmin = result.logoProxyAdmin;
      logoInstance = result.logoInstance;
    } else {
      console.log("Logo instance deployment error - Parameter missing!");
    }
  }
  logoInstanceAddr = await logoInstance?.getAddress() || LOGO_INSTANCE_ADDRESS;
  logoProxyAdminAddr = await logoProxyAdmin?.getAddress() || LOGO_PROXY_ADMIN_ADDRESS;

  if (UPGRADE_DLOGOS_OWNER) {
    if (dLogosOwnerProxyAdminAddr != "" && dLogosOwnerInstanceAddr != "" && dLogosOwnerImplAddr != "") {
      await upgrade(
        "DLogosOwner",
        dLogosOwnerProxyAdminAddr,
        dLogosOwnerInstanceAddr,
        dLogosOwnerImplAddr
      );
    } else {
      console.log(`DLogosOwner upgrade error - Parameter missing!`);
    }
  }

  if (UPGRADE_DLOGOS_BACKER) {
    if (dLogosBackerProxyAdminAddr != "" && dLogosBackerInstanceAddr != "" && dLogosBackerImplAddr != "") {
      await upgrade(
        "DLogosBacker",
        dLogosBackerProxyAdminAddr,
        dLogosBackerInstanceAddr,
        dLogosBackerImplAddr
      );
    } else {
      console.log(`DLogosBacker upgrade error - Parameter missing!`);
    }
  }

  if (UPGRADE_DLOGOS_CORE) {
    if (dLogosCoreProxyAdminAddr != "" && dLogosCoreInstanceAddr != "" && dLogosCoreImplAddr != "") {
      await upgrade(
        "DLogosCore",
        dLogosCoreProxyAdminAddr,
        dLogosCoreInstanceAddr,
        dLogosCoreImplAddr
      );
    } else {
      console.log(`DLogosCore upgrade error - Parameter missing!`);
    }
  }

  if (UPGRADE_LOGO) {
    if (logoProxyAdminAddr != "" && logoInstanceAddr != "" && logoImplAddr != "") {
      await upgrade(
        "Logo",
        logoProxyAdminAddr,
        logoInstanceAddr,
        logoImplAddr
      );
    } else {
      console.log(`Logo upgrade error - Parameter missing!`);
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
