import { ethers, upgrades } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import {
  ZERO_ADDRESS,
  BIGINT_1E14,
  BIGINT_1E13,
  BIGINT_1E12,
  ONE_DAY,
} from "./_helpers/constants";

describe("DLogosCore Testing", () => {
  it("Test prepEnv", async () => {
    const env = await loadFixture(prepEnv);

    // check ownership
    expect(await env.dLogosCore.owner()).equals(
      env.deployer.address
    );

    // check public variables
    expect(await env.dLogosCore.dLogosOwner()).equals(
      await env.dLogosOwner.getAddress()
    );
    expect(await env.dLogosCore.dLogosBacker()).equals(
      await env.dLogosBacker.getAddress()
    );
    expect(await env.dLogosCore.logoId()).equals(
      1
    );
  });

  describe("{initialize} function", () => {
    describe("Reverts", () => {
      it("Implementation's {initialize} function should be locked", async () => {
        const env = await loadFixture(prepEnv);

        const dLogosCore = await env.dLogosCoreF.deploy();
        await expect(
          dLogosCore.initialize(
            ZERO_ADDRESS,
            ZERO_ADDRESS,
            ZERO_ADDRESS,
          )
        ).to.be.revertedWithCustomError(
          dLogosCore,
          "InvalidInitialization()"
        );
      });

      it("Should revert when call {initialize} function twice", async () => {
        const env = await loadFixture(prepEnv);

        await expect(
          env.dLogosCore.initialize(
            ZERO_ADDRESS,
            ZERO_ADDRESS,
            ZERO_ADDRESS,
          )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidInitialization()"
        );
      });
    });
  });

  describe("{createLogo}, {getLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithCreateLogo);

      const logo1 = await env.dLogosCore.getLogo(1);
      expect(logo1.id).equals(
        1,
      );
      expect(logo1.title).equals(
        env.logo1Title,
      );
      expect(logo1.proposer).equals(
        env.proposer1.address
      );
      expect(logo1.proposerFee).equals(
        env.logo1PFee
      );
      expect(logo1.scheduledAt).equals(
        0
      );
      expect(logo1.mediaAssetURL).equals(
        ""
      );
      expect(logo1.minimumPledge).equals(
        BIGINT_1E13
      );
      expect(logo1.crowdfundStartAt).equals(
        await time.latest()
      );
      expect(logo1.crowdfundEndAt).equals(
        BigInt(await time.latest()) + env.logo1CrowdfundNumberOfDays * ONE_DAY
      );
      expect(logo1.splitForAffiliate).equals(
        ZERO_ADDRESS
      );
      expect(logo1.splitForSpeaker).equals(
        ZERO_ADDRESS
      );
      expect(logo1.rejectionDeadline).equals(
        0
      );
      expect(logo1.status.isCrowdfunding).equals(
        true
      );
      expect(logo1.status.isUploaded).equals(
        false
      );
      expect(logo1.status.isDistributed).equals(
        false
      );
      expect(logo1.status.isRefunded).equals(
        false
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithCreateLogo);

      await expect(env.createLogoTx)
        .emit(env.dLogosCore, "LogoCreated")
        .withArgs(
          env.proposer1.address,
          1,
          await time.latest(),
        ).emit(env.dLogosCore, "CrowdfundToggled")
        .withArgs(
          env.proposer1.address,
          true
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await loadFixture(prepEnvWithCreateLogo);

        const env1 = await prepEnvWithPauseOrUnpauseTrue(env);

        await expect(
          env1.dLogosCore
            .connect(env1.proposer1)
            .createLogo(
              0,
              "",
              0
            )
        ).to.be.revertedWithCustomError(
              env1.dLogosCore,
              "EnforcedPause()"
            );
      });

      it("Should revert when {_title} param is empty string ", async () => {
        const env = await loadFixture(prepEnvWithCreateLogo);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .createLogo(
              0,
              "",
              0
            )
        ).to.be.revertedWithCustomError(
              env.dLogosCore,
              "EmptyString()"
            );
      });

      it("Should revert when {_crowdfundNumberOfDays} param > {maxDuration} ", async () => {
        const env = await loadFixture(prepEnvWithCreateLogo);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .createLogo(
              0,
              env.logo1Title,
              61,
            )
        ).to.be.revertedWithCustomError(
              env.dLogosCore,
              "CrowdfundDurationExceeded()"
            );
      });
    });
  });
});

async function prepEnv() {
  const [deployer, nonDeployer, proposer1, ...otherSigners] = await ethers.getSigners();

  // deploy DLogosOwner mock
  const dLogosOwnerF = await ethers.getContractFactory("DLogosOwnerMock");
  const dLogosOwner = await dLogosOwnerF.deploy();

  // deploy DLogosBacker mock
  const dLogosBackerF = await ethers.getContractFactory("DLogosBackerMock");
  const dLogosBacker = await dLogosBackerF.deploy();

  // deploy DLogosSplitsHelper
  const dLogosSplitsHelperF = await ethers.getContractFactory("DLogosSplitsHelper");
  const dLogosSplitsHelper = await dLogosSplitsHelperF.deploy();

  // deploy and initialize DLogosCore
  const trustedForwarder = "0x92371F3c1Bda1fB4F67a7984FDa54d60b0e6c6Ef"; // random address
  const dLogosCoreF = await ethers.getContractFactory("DLogosCore", {
    libraries: {
      DLogosSplitsHelper: await dLogosSplitsHelper.getAddress(),
    }
  });
  const dLogosCoreProxy = await upgrades.deployProxy(
    dLogosCoreF,
    [
      trustedForwarder,
      await dLogosOwner.getAddress(),
      await dLogosBacker.getAddress()
    ],
    {
      initializer: "initialize",
      unsafeAllowLinkedLibraries: true,
    }
  );
  const dLogosCore = dLogosCoreF.attach(await dLogosCoreProxy.getAddress());

  return {
    deployer,
    nonDeployer,
    proposer1,

    trustedForwarder,

    dLogosOwner,
    dLogosBacker,

    dLogosCoreF,
    dLogosCoreProxy,
    dLogosCore    
  };
};

async function prepEnvWithCreateLogo() {
  const prevEnv = await loadFixture(prepEnv);

  const logo1PFee = 100000n; // 10%
  const logo1Title = "First Logo";
  const logo1CrowdfundNumberOfDays = 4n;
  const createLogoTx = await prevEnv.dLogosCore
    .connect(prevEnv.proposer1)
    .createLogo(
      logo1PFee,
      logo1Title,
      logo1CrowdfundNumberOfDays
    );

  return {
    ...prevEnv,

    logo1PFee,
    logo1Title,
    logo1CrowdfundNumberOfDays,
    createLogoTx,
  };
};

async function prepEnvWithPauseOrUnpauseTrue(prevEnv?: any) {
  if (prevEnv == undefined) {
    prevEnv = await loadFixture(prepEnv);
  }

  const pauseTx = await prevEnv.dLogosCore
    .connect(prevEnv.deployer)
    .pauseOrUnpause(true);

  return {
    ...prevEnv,

    pauseTx,
  };
}
