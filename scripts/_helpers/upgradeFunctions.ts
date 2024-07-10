import { ethers } from "hardhat";

export async function upgrade(
	contractName: string,
	proxyAdminAddr: string,
	proxyAddr: string,
	newImplAddr: string
) {
	console.log(`UPGRADING ${contractName}`);

	const proxyAdminF = await ethers.getContractFactory("ProxyAdmin");
	const proxyAdmin = proxyAdminF.attach(proxyAdminAddr);
	const proxyAdminFunc = proxyAdmin.getFunction("upgradeAndCall");
	let tx = await proxyAdminFunc.send(
		proxyAddr,
		newImplAddr,
		"0x"
	);
	let txReceipt = await tx.wait();

	console.log(`UPGRADED ${contractName} at:${txReceipt?.hash}`);
	console.log("\n");
}
