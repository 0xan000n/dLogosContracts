import { ethers, run, network } from "hardhat";
import { TRANSPARENT_UPGRADEABLE_PROXY_ADMIN_SLOT } from "./constants";

//-----------------------Library-----------------------//
export async function deployDLogosCoreHelperLibrary() {
	console.log("DEPLOYING DLogosCoreHelper library");

	// factories
	const dLogosCoreHelperF = await ethers.getContractFactory("DLogosCoreHelper");

	const dLogosCoreHelper = await dLogosCoreHelperF.deploy();
	await dLogosCoreHelper.waitForDeployment();
	const dLogosCoreHelperAddr = await dLogosCoreHelper.getAddress();

	// verify
	if (network.name != "hardhat") {
		await run(`verify:verify`, {
			address: dLogosCoreHelperAddr,
			constructorArguments: [],
		});
	}

	console.log(`***DEPLOYED DLogosCoreHelper library at:${dLogosCoreHelperAddr}***`);
	console.log("\n");

	return dLogosCoreHelper;
}

//-----------------------Implementation-----------------------//
export async function deployDLogosOwnerImplementation() {
	console.log("DEPLOYING DLogosOwner Implementation");

	// factories
	const dLogosOwnerF = await ethers.getContractFactory("DLogosOwner");

	const dLogosOwnerImpl = await dLogosOwnerF.deploy();
	await dLogosOwnerImpl.waitForDeployment();
	const dLogosOwnerImplAddr = await dLogosOwnerImpl.getAddress();

	// verify
	if (network.name != "hardhat") {
		await run(`verify:verify`, {
			address: dLogosOwnerImplAddr,
			constructorArguments: [],
		});
	}

	console.log(`***DEPLOYED DLogosOwner Implementation at:${dLogosOwnerImplAddr}***`);
	console.log("\n");

	return dLogosOwnerImpl;
}

export async function deployDLogosBackerImplementation() {
	console.log("DEPLOYING DLogosBacker Implementation");

	// factories
	const dLogosBackerF = await ethers.getContractFactory("DLogosBacker");

	const dLogosBackerImpl = await dLogosBackerF.deploy();
	await dLogosBackerImpl.waitForDeployment();
	const dLogosBackerImplAddr = await dLogosBackerImpl.getAddress();

	// verify
	if (network.name != "hardhat") {
		await run(`verify:verify`, {
			address: dLogosBackerImplAddr,
			constructorArguments: [],
		});
	}

	console.log(`***DEPLOYED DLogosBacker Implementation at:${dLogosBackerImplAddr}***`);
	console.log("\n");

	return dLogosBackerImpl;
}

export async function deployDLogosCoreImplementation(
	dLogosCoreHelperAddr: string,
) {
	console.log("DEPLOYING DLogosCore Implementation");

	// factories
	const dLogosCoreF = await ethers.getContractFactory("DLogosCore", {
		libraries: {
			DLogosCoreHelper: dLogosCoreHelperAddr,
		},
	});

	const dLogosCoreImpl = await dLogosCoreF.deploy();
	await dLogosCoreImpl.waitForDeployment();
	const dLogosCoreImplAddr = await dLogosCoreImpl.getAddress();

	// verify
	if (network.name != "hardhat") {
		await run(`verify:verify`, {
			address: dLogosCoreImplAddr,
			constructorArguments: [],
			libraries: {
				DLogosCoreHelper: dLogosCoreHelperAddr,
			}
		});
	}

	console.log(`***DEPLOYED DLogosCore Implementation at:${dLogosCoreImplAddr}***`);
	console.log("\n");

	return dLogosCoreImpl;
}

export async function deployLogoImplementation() {
	console.log("DEPLOYING Logo Implementation");

	// factories
	const logoF = await ethers.getContractFactory("Logo");

	const logoImpl = await logoF.deploy();
	await logoImpl.waitForDeployment();
	const logoImplAddr = await logoImpl.getAddress();

	// verify
	if (network.name != "hardhat") {
		await run(`verify:verify`, {
			address: logoImplAddr,
			constructorArguments: [],
		});
	}

	console.log(`***DEPLOYED Logo Implementation at:${logoImplAddr}***`);
	console.log("\n");

	return logoImpl;
}

//-----------------------Instance-----------------------//
export async function deployDLogosOwnerInstance(
	dLogosOwnerImplAddr: string,
	ownerAddr: string,
	dLogosAddr: string,
	communityAddr: string,
) {
	console.log("DEPLOYING DLogosOwner Instance");
	
	// factories
	const dLogosOwnerF = await ethers.getContractFactory("DLogosOwner");
	const transparentUpgradeableProxyF = await ethers.getContractFactory("TransparentUpgradeableProxy");

	const dLogosOwnerImpl = dLogosOwnerF.attach(dLogosOwnerImplAddr);
	const dLogosOwnerInitFunc = dLogosOwnerImpl.getFunction("initialize");
	const initTx = await dLogosOwnerInitFunc.populateTransaction(
		dLogosAddr,
		communityAddr,
	);

	console.log("DEPLOYING TransparentUpgradeableProxy");

	const dLogosOwnerProxy = await transparentUpgradeableProxyF.deploy(
		dLogosOwnerImplAddr,
		ownerAddr,
		initTx.data!
	);
	await dLogosOwnerProxy.waitForDeployment();
	const dLogosOwnerProxyAddr = await dLogosOwnerProxy.getAddress();

	// fetch ProxyAdmin address and init
	const addrString = await ethers.provider.getStorage(
		dLogosOwnerProxyAddr, 
		TRANSPARENT_UPGRADEABLE_PROXY_ADMIN_SLOT
	);
	const proxyAdminAddr = ethers.getAddress("0x" + addrString.slice(26));
	const proxyAdminF = await ethers.getContractFactory("ProxyAdmin");
	const dLogosOwnerProxyAdmin = proxyAdminF.attach(proxyAdminAddr);
	// // verify
	// if (network.name != "hardhat") {
	// 	await run("verify:verify", {
	// 		address: proxyAdminAddr,
	// 		constructorArguments: [
	// 			ownerAddr,
	// 		],
	// 	});
	// }
	console.log(`***DEPLOYED DLogosOwner ProxyAdmin at:${proxyAdminAddr}***`);	

	// verify
	if (network.name != "hardhat") {
		await run("verify:verify", {
			address: dLogosOwnerProxyAddr,
			constructorArguments: [
				dLogosOwnerImplAddr,
				ownerAddr,
				initTx.data!,
			],
		});
	}

	const dLogosOwnerInstance = dLogosOwnerF.attach(dLogosOwnerProxyAddr);

	console.log(`***DEPLOYED DLogosOwner Instance at:${dLogosOwnerProxyAddr}***`);
	console.log("\n");

	return {
		dLogosOwnerProxyAdmin,
		dLogosOwnerInstance,
	};
}

export async function deployDLogosBackerInstance(
	dLogosBackerImplAddr: string,
	ownerAddr: string,
	trustedForwarderAddr: string,
	dLogosOwnerAddr: string,
) {
	console.log("DEPLOYING DLogosBacker Instance");
	
	// factories
	const dLogosBackerF = await ethers.getContractFactory("DLogosBacker");
	const transparentUpgradeableProxyF = await ethers.getContractFactory("TransparentUpgradeableProxy");

	const dLogosBackerImpl = dLogosBackerF.attach(dLogosBackerImplAddr);
	const dLogosBackerInitFunc = dLogosBackerImpl.getFunction("initialize");
	const initTx = await dLogosBackerInitFunc.populateTransaction(
		trustedForwarderAddr,
		dLogosOwnerAddr,
	);

	console.log("DEPLOYING TransparentUpgradeableProxy");

	const dLogosBackerProxy = await transparentUpgradeableProxyF.deploy(
		dLogosBackerImplAddr,
		ownerAddr,
		initTx.data!
	);
	await dLogosBackerProxy.waitForDeployment();
	const dLogosBackerProxyAddr = await dLogosBackerProxy.getAddress();

	// fetch ProxyAdmin address and init
	const addrString = await ethers.provider.getStorage(
		dLogosBackerProxyAddr, 
		TRANSPARENT_UPGRADEABLE_PROXY_ADMIN_SLOT
	);
	const proxyAdminAddr = ethers.getAddress("0x" + addrString.slice(26));
	// // verify
	// if (network.name != "hardhat") {
	// 	await run("verify:verify", {
	// 		address: proxyAdminAddr,
	// 		constructorArguments: [
	// 			ownerAddr,
	// 		],
	// 	});
	// }
	const proxyAdminF = await ethers.getContractFactory("ProxyAdmin");
	const dLogosBackerProxyAdmin = proxyAdminF.attach(proxyAdminAddr);
	console.log(`***DEPLOYED DLogosBacker ProxyAdmin at:${proxyAdminAddr}***`);

	// verify
	if (network.name != "hardhat") {
		await run("verify:verify", {
			address: dLogosBackerProxyAddr,
			constructorArguments: [
				dLogosBackerImplAddr,
				ownerAddr,
				initTx.data!,
			],
		});
	}

	const dLogosBackerInstance = dLogosBackerF.attach(dLogosBackerProxyAddr);

	console.log(`***DEPLOYED DLogosBacker Instance at:${dLogosBackerProxyAddr}***`);
	console.log("\n");

	return {
		dLogosBackerProxyAdmin,
		dLogosBackerInstance,
	};
}

export async function deployDLogosCoreInstance(
	dLogosCoreHelperAddr: string,
	dLogosCoreImplAddr: string,
	ownerAddr: string,
	dLogosOwnerAddr: string,
) {
	console.log("DEPLOYING DLogosCore Instance");
	
	// factories
	const dLogosCoreF = await ethers.getContractFactory("DLogosCore", {
		libraries: {
			DLogosCoreHelper: dLogosCoreHelperAddr,
		},
	});
	const transparentUpgradeableProxyF = await ethers.getContractFactory("TransparentUpgradeableProxy");

	const dLogosCoreImpl = dLogosCoreF.attach(dLogosCoreImplAddr);
	const dLogosCoreInitFunc = dLogosCoreImpl.getFunction("initialize");
	const initTx = await dLogosCoreInitFunc.populateTransaction(
		dLogosOwnerAddr,
	);

	console.log("DEPLOYING TransparentUpgradeableProxy");

	const dLogosCoreProxy = await transparentUpgradeableProxyF.deploy(
		dLogosCoreImplAddr,
		ownerAddr,
		initTx.data!
	);
	await dLogosCoreProxy.waitForDeployment();
	const dLogosCoreProxyAddr = await dLogosCoreProxy.getAddress();

	// fetch ProxyAdmin address and init
	const addrString = await ethers.provider.getStorage(
		dLogosCoreProxyAddr, 
		TRANSPARENT_UPGRADEABLE_PROXY_ADMIN_SLOT
	);
	const proxyAdminAddr = ethers.getAddress("0x" + addrString.slice(26));
	// // verify
	// if (network.name != "hardhat") {
	// 	await run("verify:verify", {
	// 		address: proxyAdminAddr,
	// 		constructorArguments: [
	// 			ownerAddr,
	// 		],
	// 	});
	// }
	const proxyAdminF = await ethers.getContractFactory("ProxyAdmin");
	const dLogosCoreProxyAdmin = proxyAdminF.attach(proxyAdminAddr);
	console.log(`***DEPLOYED DLogosCore ProxyAdmin at:${proxyAdminAddr}***`);	

	// verify
	if (network.name != "hardhat") {
		await run("verify:verify", {
			address: dLogosCoreProxyAddr,
			constructorArguments: [
				dLogosCoreImplAddr,
				ownerAddr,
				initTx.data!,
			],
		});
	}

	const dLogosCoreInstance = dLogosCoreF.attach(dLogosCoreProxyAddr);

	console.log(`***DEPLOYED DLogosCore Instance at:${dLogosCoreProxyAddr}***`);
	console.log("\n");

	return {
		dLogosCoreProxyAdmin,
		dLogosCoreInstance,
	};
}

export async function deployLogoInstance(
	logoImplAddr: string,
	ownerAddr: string,
	dLogosOwnerAddr: string,
) {
	console.log("DEPLOYING Logo Instance");
	
	// factories
	const logoF = await ethers.getContractFactory("Logo");
	const transparentUpgradeableProxyF = await ethers.getContractFactory("TransparentUpgradeableProxy");

	const logoImpl = logoF.attach(logoImplAddr);
	const logoInitFunc = logoImpl.getFunction("initialize");
	const initTx = await logoInitFunc.populateTransaction(
		dLogosOwnerAddr,
	);

	console.log("DEPLOYING TransparentUpgradeableProxy");

	const logoProxy = await transparentUpgradeableProxyF.deploy(
		logoImplAddr,
		ownerAddr,
		initTx.data!
	);
	await logoProxy.waitForDeployment();
	const logoProxyAddr = await logoProxy.getAddress();

	// fetch ProxyAdmin address and init
	const addrString = await ethers.provider.getStorage(
		logoProxyAddr, 
		TRANSPARENT_UPGRADEABLE_PROXY_ADMIN_SLOT
	);
	const proxyAdminAddr = ethers.getAddress("0x" + addrString.slice(26));
	// // verify
	// if (network.name != "hardhat") {
	// 	await run("verify:verify", {
	// 		address: proxyAdminAddr,
	// 		constructorArguments: [
	// 			ownerAddr,
	// 		],
	// 	});
	// }
	const proxyAdminF = await ethers.getContractFactory("ProxyAdmin");
	const logoProxyAdmin = proxyAdminF.attach(proxyAdminAddr);
	console.log(`***DEPLOYED Logo ProxyAdmin at:${proxyAdminAddr}***`);

	// verify
	if (network.name != "hardhat") {
		await run("verify:verify", {
			address: logoProxyAddr,
			constructorArguments: [
				logoImplAddr,
				ownerAddr,
				initTx.data!,
			],
		});
	}

	const logoInstance = logoF.attach(logoProxyAddr);

	console.log(`***DEPLOYED Logo Instance at:${logoProxyAddr}***`);
	console.log("\n");

	return {
		logoProxyAdmin,
		logoInstance,
	};
}
