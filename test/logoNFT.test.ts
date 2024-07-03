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

  describe("{safeMint}, {getInfo} function", () => {
    describe("Should make changes to the storage", () => {
      it("when caller is backer", async () => {
        const env = await loadFixture(prepEnvWithSafeMintByBacker);
  
        expect(await env.logo.tokenIdCounter()).equals(
          1n
        );
        expect(await env.logo.ownerOf(1)).equals(
          env.backer.address
        );
        const info = await env.logo.getInfo(1);
        expect(info.owner).equals(
          env.backer.address
        );
        expect(info.logoId).equals(
          env.logoIdByBacker
        );
        expect(info.status).equals(
          0n
        );
      });

      it("when caller is speaker", async () => {
        const env = await loadFixture(prepEnvWithSafeMintBySpeaker);
  
        expect(await env.logo.tokenIdCounter()).equals(
          2n
        );
        expect(await env.logo.ownerOf(2)).equals(
          env.speaker.address
        );
        const info = await env.logo.getInfo(2);
        expect(info.owner).equals(
          env.speaker.address
        );
        expect(info.logoId).equals(
          env.logoIdBySpeaker
        );
        expect(info.status).equals(
          1n
        );
      });
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithSafeMintByBacker);

      await expect(env.safeMintTx)
        .emit(env.logo, "Minted")
        .withArgs(
          env.backer.address,
          1,
          env.logoIdByBacker,
          true,
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await prepEnvWithPauseOrUnpauseTrue(
          await loadFixture(prepEnv)
        );

        await expect(
          env.dLogosBacker
            .connect(env.deployer)
            .crowdfund(
              env.backer.address,
              0,
              ZERO_ADDRESS
            )
        ).to.be.revertedWithCustomError(
          env.logo,
          "EnforcedPause()"
        );
      });

      it("Should revert when caller is not backer nor core contracts", async () => {
        const env = await loadFixture(prepEnv);

        await expect(
          env.logo
            .connect(env.deployer)
            .safeMint(
              ZERO_ADDRESS,
              0,
              false,
            )
        ).to.be.revertedWithCustomError(
          env.logo,
          "CallerNotDLogos()"
        );
      });

        it("Should revert when {_to} is zero address", async () => {
          const env = await loadFixture(prepEnv);

          await expect(
            env.dLogosBacker
              .connect(env.deployer)
              .crowdfund(
                ZERO_ADDRESS,
                0,
                ZERO_ADDRESS,
              )
          ).to.be.revertedWithCustomError(
            env.logo,
            "ERC721InvalidReceiver"
          ).withArgs(
            ZERO_ADDRESS
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

  // deploy DLogosBacker mock
  const dLogosBackerF = await ethers.getContractFactory("DLogosBackerMock");
  const dLogosBacker = await dLogosBackerF.deploy(dLogosOwnerAddr);

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
    dLogosBacker,
    dLogosCore,

    logoF,
    logoProxy,
    logo,
  };
};

async function prepEnvWithSafeMintByBacker() {
  const prevEnv = await loadFixture(prepEnv);

  const logoIdByBacker = 1;
  const safeMintTx = await prevEnv.dLogosBacker
    .connect(prevEnv.deployer)
    .crowdfund(
      prevEnv.backer.address,
      logoIdByBacker,
      ZERO_ADDRESS,
    );

  return {
    ...prevEnv,

    logoIdByBacker,
    
    safeMintTx,
  };
}

async function prepEnvWithSafeMintBySpeaker() {
  const prevEnv = await loadFixture(prepEnvWithSafeMintByBacker);

  const logoIdBySpeaker = 2;
  const safeMintTx = await prevEnv.dLogosCore
    .connect(prevEnv.deployer)
    .setSpeakerStatus(
      prevEnv.speaker.address,
      logoIdBySpeaker,
      0,
    );

  return {
    ...prevEnv,

    logoIdBySpeaker,
    
    safeMintTx,
  };
}

async function prepEnvWithSetBaseURI() {
  const prevEnv = await loadFixture(prepEnvWithSafeMintBySpeaker);

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
