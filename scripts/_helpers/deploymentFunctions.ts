import { ethers, run } from "hardhat";

export async function deployDLogosImplementation() {
	console.log("DEPLOYING DLogos Implementation");

	// factories
	const dLogosF = await ethers.getContractFactory("DLogos");

	const dLogosImpl = await dLogosF.deploy();
	await dLogosImpl.waitForDeployment();
	const dLogosImplAddr = await dLogosImpl.getAddress();

	// verify
	await run(`verify:verify`, {
		address: dLogosImplAddr,
		constructorArguments: [],
	});

	console.log(`DEPLOYED DLogos Implementation at:${dLogosImplAddr}`);
	console.log("\n");

	return dLogosImpl;
}

export async function deployDLogosInstance(
	dLogosImplAddr: string,
	ownerAddr: string
) {
	console.log("DEPLOYING DLogos Instance");
	
	// factories
	const dLogosF = await ethers.getContractFactory("DLogos");
	const transparentUpgradeableProxyF = await ethers.getContractFactory("TransparentUpgradeableProxy");

	const dLogosImpl = dLogosF.attach(dLogosImplAddr);
	const dLogosInitFunc = dLogosImpl.getFunction("initialize");
	const initTx = await dLogosInitFunc.populateTransaction();

	console.log("DEPLOYING TransparentUpgradeableProxy");

	const dLogosProxy = await transparentUpgradeableProxyF.deploy(
		dLogosImplAddr,
		ownerAddr,
		initTx.data!
	);
	await dLogosProxy.waitForDeployment();
	const dLogosProxyAddr = await dLogosProxy.getAddress();

	// verify
	await run(`verify:verify`, {
		address: dLogosProxyAddr,
		constructorArguments: [
			dLogosImplAddr,
			ownerAddr,
			initTx.data!
		],
	});

	const dLogosInstance = dLogosF.attach(dLogosProxyAddr);

	console.log(`DEPLOYED DLogos Instance at:${dLogosProxyAddr}`);
	console.log("\n");

	return dLogosInstance;
}
