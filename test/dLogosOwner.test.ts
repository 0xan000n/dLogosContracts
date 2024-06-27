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

      it("Should revert when call {initialize} function twice", async () => {
        const env = await loadFixture(prepEnv);

        await expect(
          env.dLogosOwner.initialize(
            ZERO_ADDRESS,
            ZERO_ADDRESS
          )
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "InvalidInitialization()"
        );
      });
    });
  });

  describe("{setRejectThreshold} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithRejectThreshold);

      expect(await env.dLogosOwner.rejectThreshold()).equals(env.rejectThreshold);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithRejectThreshold);

      await expect(env.setRejectThresholdTx)
        .emit(env.dLogosOwner, "RejectThresholdUpdated")
        .withArgs(env.rejectThreshold);
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithRejectThreshold);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setRejectThreshold(0)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
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

async function prepEnvWithRejectThreshold() {
  const prevEnv = await loadFixture(prepEnv);

  const rejectThreshold = 6000;
  const setRejectThresholdTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setRejectThreshold(rejectThreshold);

  return {
    ...prevEnv,

    rejectThreshold,
    setRejectThresholdTx,
  };
};
