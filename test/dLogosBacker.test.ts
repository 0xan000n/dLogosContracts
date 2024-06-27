import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

describe("DLogosBacker Tests", () => {
  it("Test prepEnv", async () => {

  });
});

async function prepEnv() {
  const [deployer, ...otherSigners] = await ethers.getSigners();
};
