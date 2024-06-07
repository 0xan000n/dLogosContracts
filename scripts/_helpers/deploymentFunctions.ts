import { ethers } from "hardhat";
import { DLogos } from "../../typechain-types";

export async function deployDLogosImplementation() {
	console.log("DEPLOYING DLogos Implementation");

	// factories
	const dLogosF = await ethers.getContractFactory("DLogos");

	const dLogosImpl = await dLogosF.deploy();
	await dLogosImpl.waitForDeployment();
	const dLogosImplAddr = await dLogosImpl.getAddress();

	console.log(`DEPLOYED DLogos Implementation at:${dLogosImplAddr}`);
	console.log("\n");

	return dLogosImpl;
}

export async function deployDLogosInstance(
	dLogosImpl: DLogos,
	ownerAddr: string
) {
	console.log("DEPLOYING DLogos Instance");
	
	// factories
	const transparentUpgradeableProxyF = await ethers.getContractFactory("TransparentUpgradeableProxy");

	const dLogosImplAddr = await dLogosImpl.getAddress();
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

	const dLogosF = await ethers.getContractFactory("DLogos");
	const dLogosInstance = dLogosF.attach(dLogosProxyAddr);

	console.log(`DEPLOYED DLogos Instance at:${dLogosProxyAddr}`);
	console.log("\n");

	return dLogosInstance;
}
