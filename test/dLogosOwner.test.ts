import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import { ZERO_ADDRESS } from "./_helpers/constants";

describe("DLogosOwner Tests", () => {
  it("Test prepEnv", async () => {
    const env = await loadFixture(prepEnv);

    // check ownership
    expect(await env.dLogosOwner.owner()).equals(
      env.deployer.address
    );

    // check public variables
    expect(await env.dLogosOwner.dLogos()).equals(
      env.dLogos.address
    );
    expect(await env.dLogosOwner.community()).equals(
      env.community.address
    );
    expect(await env.dLogosOwner.dLogosFee()).equals(
      100000
    );
    expect(await env.dLogosOwner.communityFee()).equals(
      100000
    );
    expect(await env.dLogosOwner.affiliateFee()).equals(
      50000
    );
    expect(await env.dLogosOwner.rejectThreshold()).equals(
      5000
    );
    expect(await env.dLogosOwner.maxDuration()).equals(
      60
    );
    expect(await env.dLogosOwner.rejectionWindow()).equals(
      7
    );
  });

  describe("{initialize} function", () => {
    describe("Reverts", () => {
      it("Implementation's {initialize} function should be locked", async () => {
        const env = await loadFixture(prepEnv);

        const dLogosOwner = await env.dLogosOwnerF.deploy();
        await expect(
          dLogosOwner.initialize(
            ZERO_ADDRESS,
            ZERO_ADDRESS
          )
        ).to.be.revertedWithCustomError(
          dLogosOwner,
          "InvalidInitialization()"
        );
      });
    });
  });
});

async function prepEnv() {
  const [deployer, dLogos, community, alice, ...otherSigners] = await ethers.getSigners();

  const dLogosOwnerF = await ethers.getContractFactory("DLogosOwner");
  const dLogosOwnerProxy = await upgrades.deployProxy(
    dLogosOwnerF,
    [
      dLogos.address,
      community.address
    ],
    {
      initializer: "initialize",
    }
  );
  const dLogosOwner = dLogosOwnerF.attach(await dLogosOwnerProxy.getAddress());

  return {
    deployer,
    dLogos,
    community,
    alice,

    dLogosOwnerF,
    dLogosOwnerProxy,
    dLogosOwner,
  };
};
