import { ethers } from "hardhat";
import {
	ProxyAdmin,
	DLogos
} from "../../typechain-types";

export async function upgradeDLogos(
	proxyAdmin: ProxyAdmin,
	newDLogosImpl: DLogos
) {
	console.log("UPGRADING Dlogos");

	const proxyAdminAddr = await proxyAdmin.getAddress();
	const newDLogosImplAddr = await newDLogosImpl.getAddress();
	const proxyAdminFunc = proxyAdmin.getFunction("upgradeAndCall");
	let tx = await proxyAdminFunc.send(
		proxyAdminAddr,
		newDLogosImplAddr,
		"0x"
	);
	let txReceipt = await tx.wait();

	console.log(`UPGRADED at:${txReceipt?.hash}`);
	console.log("\n");
}
