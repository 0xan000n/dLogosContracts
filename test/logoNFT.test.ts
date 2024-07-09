import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import {
  ZERO_ADDRESS,
} from "./_helpers/constants";

describe("Logo NFT Tests", () => {
  it("Test prepEnv", async () => {
    const env = await loadFixture(prepEnv);

    // check ownership
    expect(await env.logo.owner()).equals(
      env.deployer.address
    );

    // check public variables
    expect(await env.logo.dLogosOwner()).equals(
      await env.dLogosOwner.getAddress()
    );
  });

  describe("{initialize} function", () => {
    describe("Reverts", () => {
      it("Implementation's {initialize} function should be locked", async () => {
        const env = await loadFixture(prepEnv);

        const logo = await env.logoF.deploy();
        await expect(
          logo.initialize(
            ZERO_ADDRESS
          )
        ).to.be.revertedWithCustomError(
          logo,
          "InvalidInitialization()"
        );
      });

      it("Should revert when call {initialize} function twice", async () => {
        const env = await loadFixture(prepEnv);

        await expect(
          env.logo.initialize(
            ZERO_ADDRESS
          )
        ).to.be.revertedWithCustomError(
          env.logo,
          "InvalidInitialization()"
        );
      });
    });
  });

  describe("{safeMintBatchByDLogos}, {getInfo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSafeMintBatchByDLogosCore);

      expect(await env.logo.tokenIdCounter()).equals(
        3n,
      );
      // token#1
      expect(await env.logo.ownerOf(1)).equals(
        env.token1Recipient,
      );
      const info1 = await env.logo.getInfo(1);
      expect(info1.logoId).equals(
        env.logoId,
      );
      expect(info1.status).equals(
        1n,
      );
      // token#2
      expect(await env.logo.ownerOf(2)).equals(
        env.token2Recipient,
      );
      const info2 = await env.logo.getInfo(2);
      expect(info2.logoId).equals(
        env.logoId,
      );
      expect(info2.status).equals(
        2n,
      );
      // token#3
      expect(await env.logo.ownerOf(3)).equals(
        env.token3Recipient,
      );
      const info3 = await env.logo.getInfo(3);
      expect(info3.logoId).equals(
        env.logoId,
      );
      expect(info3.status).equals(
        3n,
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithSafeMintBatchByDLogosCore);

      await expect(env.safeMintBatchByDLogosCoreTx)
        .emit(env.logo, "Minted")
        .withArgs(
          env.token1Recipient,
          1,
          env.logoId,
          1,
        );
      await expect(env.safeMintBatchByDLogosCoreTx)
        .emit(env.logo, "Minted")
        .withArgs(
          env.token2Recipient,
          2,
          env.logoId,
          2,
        );
      await expect(env.safeMintBatchByDLogosCoreTx)
        .emit(env.logo, "Minted")
        .withArgs(
          env.token3Recipient,
          3,
          env.logoId,
          3,
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await prepEnvWithPauseOrUnpauseTrue(
          await loadFixture(prepEnv)
        );

        await expect(
          env.dLogosCore
            .connect(env.deployer)
            .distributeRewards(
              0,
              true,
            )
        ).to.be.revertedWithCustomError(
          env.logo,
          "EnforcedPause()"
        );
      });

      it("Should revert when caller is not {DLogosCore} contract", async () => {
        const env = await loadFixture(prepEnv);

        await expect(
          env.logo
            .connect(env.deployer)
            .safeMintBatchByDLogosCore(
              [
                ZERO_ADDRESS
              ],
              0,
              [
                0
              ],
            )
        ).to.be.revertedWithCustomError(
          env.logo,
          "CallerNotDLogosCore()"
        );
      });

      it("Should revert when array param length mismtach", async () => {
        const env = await loadFixture(prepEnv);

        await expect(
          env.dLogosCore
            .connect(env.deployer)
            .distributeRewardsToFailByIAA(
              1,
              true,
            )
        ).to.be.revertedWithCustomError(
          env.logo,
          "InvalidArrayArguments()"
        );
      });

      it("Should revert when one status param is undefined", async () => {
        const env = await loadFixture(prepEnv);

        await expect(
          env.dLogosCore
            .connect(env.deployer)
            .distributeRewardsToFailByIS(
              1,
              true,
            )
        ).to.be.revertedWithCustomError(
          env.logo,
          "InvalidStatus()"
        );
      });
    });
  });

  describe("{setBaseURI} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSetBaseURI);

      expect(await env.logo.baseURI()).equals(
        env.baseURI
      );
      expect(await env.logo.tokenURI(1)).equals(
        env.baseURI + "1"
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithSetBaseURI);

      await expect(env.setBaseURITx)
        .emit(env.logo, "BaseURISet")
        .withArgs(
          env.baseURI,
        );
    });

    describe("Reverts", () => {
      it("Should revert when caller is not owner", async () => {
        const env = await loadFixture(prepEnvWithSetBaseURI);

        await expect(
          env.logo
            .connect(env.nonDeployer)
            .setBaseURI(
              "",
            )
        ).to.be.revertedWithCustomError(
          env.logo,
          "OwnableUnauthorizedAccount"
        ).withArgs(
          env.nonDeployer.address
        );;
      });
    });
  });

  describe("{pauseOrUnpause(false)} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

      expect(await env.logo.paused()).equals(
        false
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

      await expect(env.unpauseTx)
        .emit(env.logo, "Unpaused")
        .withArgs(
          env.deployer.address
        );
    });

    describe("Reverts", async () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

        await expect(
          env.logo
            .connect(env.nonDeployer)
            .pauseOrUnpause(false)
        ).to.be.revertedWithCustomError(
          env.logo,
          "OwnableUnauthorizedAccount"
        ).withArgs(
          env.nonDeployer.address
        );
      });

      it("Should revert when contract is not paused", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

        await expect(
          env.logo
            .connect(env.deployer)
            .pauseOrUnpause(false)
        ).to.be.revertedWithCustomError(
          env.logo,
          "ExpectedPause()"
        );
      });
    });
  });
});

async function prepEnv() {
  const [
    deployer,
    nonDeployer,
    backer,
    speaker,
    ...otherSigners
  ] = await ethers.getSigners();

  // deploy DLogosOwner mock
  const dLogosOwnerF = await ethers.getContractFactory("DLogosOwnerMock");
  const dLogosOwner = await dLogosOwnerF.deploy();
  const dLogosOwnerAddr = await dLogosOwner.getAddress();

  // deploy and init DLogosCore mock
  const dLogosCoreF = await ethers.getContractFactory("DLogosCoreMock");
  const dLogosCore = await dLogosCoreF.deploy(dLogosOwnerAddr);
  await dLogosCore.init();
  const token1Recipient = await dLogosCore.recipients(0);
  const token2Recipient = await dLogosCore.recipients(1);
  const token3Recipient = await dLogosCore.recipients(2);

  // deploy and initialize Logo NFT
  const logoF = await ethers.getContractFactory("Logo");
  const logoProxy = await upgrades.deployProxy(
    logoF,
    [
      dLogosOwnerAddr,
    ]
  );
  const logo = logoF.attach(await logoProxy.getAddress());

  return {
    deployer,
    nonDeployer,
    backer,
    speaker,

    dLogosOwner,
    dLogosCore,

    token1Recipient,
    token2Recipient,
    token3Recipient,

    logoF,
    logoProxy,
    logo,
  };
};

async function prepEnvWithSafeMintBatchByDLogosCore() {
  const prevEnv = await loadFixture(prepEnv);

  const logoId = 1;
  const safeMintBatchByDLogosCoreTx = await prevEnv.dLogosCore
    .connect(prevEnv.deployer)
    .distributeRewards(
      logoId,
      true,
    );

  return {
    ...prevEnv,

    logoId,

    safeMintBatchByDLogosCoreTx,
  };
}

async function prepEnvWithSetBaseURI() {
  const prevEnv = await loadFixture(prepEnvWithSafeMintBatchByDLogosCore);

  const baseURI = "http://ipfs.io/";
  const setBaseURITx = await prevEnv.logo
    .connect(prevEnv.deployer)
    .setBaseURI(
      baseURI,
    );

  return {
    ...prevEnv,

    baseURI,

    setBaseURITx,
  };
}

async function prepEnvWithPauseOrUnpauseTrue(prevEnv?: any) {
  if (prevEnv == undefined) {
    prevEnv = await loadFixture(prepEnv);
  }

  const pauseTx = await prevEnv.logo
    .connect(prevEnv.deployer)
    .pauseOrUnpause(true);

  return {
    ...prevEnv,

    pauseTx,
  };
}

async function prepEnvWithPauseOrUnpauseFalse() {
  const prevEnv = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

  const unpauseTx = await prevEnv.logo
    .connect(prevEnv.deployer)
    .pauseOrUnpause(false);

  return {
    ...prevEnv,

    unpauseTx,
  };
}
