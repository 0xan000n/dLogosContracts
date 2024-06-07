import { ethers } from "hardhat";

export async function upgradeDLogos(
	proxyAdminAddr: string,
	proxyAddr: string,
	newDLogosImplAddr: string
) {
	console.log("UPGRADING Dlogos");

	const proxyAdminF = await ethers.getContractFactory("ProxyAdmin");
	const proxyAdmin = proxyAdminF.attach(proxyAdminAddr);
	const proxyAdminFunc = proxyAdmin.getFunction("upgradeAndCall");
	let tx = await proxyAdminFunc.send(
		proxyAddr,
		newDLogosImplAddr,
		"0x"
	);
	let txReceipt = await tx.wait();

	console.log(`UPGRADED Dlogos at:${txReceipt?.hash}`);
	console.log("\n");
}
