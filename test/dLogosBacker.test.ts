import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import { 
  ZERO_ADDRESS,
  BIGINT_1E14,
  BIGINT_1E13,
  BIGINT_1E12
} from "./_helpers/constants";

// TODO meta tx testing
describe("DLogosBacker Tests", () => {
  it("Test prepEnv", async () => {
    const env = await loadFixture(prepEnv);

    // check ownership
    expect(await env.dLogosBacker.owner()).equals(
      env.deployer.address
    );

    // check public variables
    expect(await env.dLogosBacker.dLogosCore()).equals(
      await env.dLogosCore.getAddress()
    );
  });

  describe("{initialize} function", () => {
    describe("Reverts", () => {
      it("Implementation's {initialize} function should be locked", async () => {
        const env = await loadFixture(prepEnv);

        const dLogosBacker = await env.dLogosBackerF.deploy();
        await expect(
          dLogosBacker.initialize(
            ZERO_ADDRESS,
            ZERO_ADDRESS
          )
        ).to.be.revertedWithCustomError(
          dLogosBacker,
          "InvalidInitialization()"
        );
      });

      it("Should revert when call {initialize} function twice", async () => {
        const env = await loadFixture(prepEnv);

        await expect(
          env.dLogosBacker.initialize(
            ZERO_ADDRESS,
            ZERO_ADDRESS
          )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "InvalidInitialization()"
        );
      });
    });
  });

  describe("{crowdfund} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithCrowdfund);

      const backersForLogo1 = await env.dLogosBacker.getBackersForLogo(1);
      expect(backersForLogo1.length).equals(
        1
      );
      expect(backersForLogo1[0].addr).equals(
        env.backer1.address
      );
      expect(backersForLogo1[0].referrer).equals(
        env.referrer1.address
      );
      expect(backersForLogo1[0].votesToReject).equals(
        false
      );
      expect(backersForLogo1[0].amount).equals(
        BIGINT_1E14
      );
      expect(await env.dLogosBacker.logoRewards(1)).equals(
        BIGINT_1E14
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithCrowdfund);

      await expect(env.crowdfundTx)
        .emit(env.dLogosBacker, "Crowdfund")
        .withArgs(
          1,
          env.backer1.address,
          BIGINT_1E14
        );
    });

    describe("Reverts", () => {
      it("Should revert when logo is not created", async () => {
        const env = await loadFixture(prepEnvWithCrowdfund);
        
        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .crowdfund(
              3,
              env.referrer1
            )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "InvalidLogoId()"
        );
      });

      it("Should revert when contract is paused", async () => {
        const env = await loadFixture(prepEnvWithCrowdfund);
        
        await env.dLogosBacker
          .connect(env.deployer)
          .pauseOrUnpause(true);

        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .crowdfund(
              1,
              env.referrer1
            )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "EnforcedPause()"
        );
      });

      it("Should revert when crowdfund is not happening", async () => {
        const env = await loadFixture(prepEnvWithCrowdfund);
        
        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .crowdfund(
              2,
              env.referrer1
            )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "LogoNotCrowdfunding()"
        );
      });

      it("Should revert when pledge < {minimumPledge}", async () => {
        const env = await loadFixture(prepEnvWithCrowdfund);
        
        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .crowdfund(
              1,
              env.referrer1,
              {
                value: BIGINT_1E12
              }
            )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "InsufficientFunds()"
        );
      });      
    });
  });

  describe("{withdrawFunds} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithWithdrawFunds);

      const backersForLogo1 = await env.dLogosBacker.getBackersForLogo(1);
      expect(backersForLogo1.length).equals(
        0
      );
      expect(await env.dLogosBacker.logoRewards(1)).equals(
        0
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithWithdrawFunds);

      await expect(env.withdrawFundsTx)
        .emit(env.dLogosBacker, "FundsWithdrawn")
        .withArgs(
          1,
          env.backer1.address,
          BIGINT_1E14
        );
    });

    describe("Reverts", () => {
      it("Should revert when logo is not created", async () => {
        const env = await loadFixture(prepEnvWithWithdrawFunds);
        
        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .withdrawFunds(
              3
            )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "InvalidLogoId()"
        );
      });
    });
  });
});

async function prepEnv() {
  const [deployer, backer1, referrer1, ...otherSigners] = await ethers.getSigners();

  // deploy and init DLogosCore mock
  const dLogosCoreF = await ethers.getContractFactory("DLogosCoreMock");
  const dLogosCore = await dLogosCoreF.deploy();
  await dLogosCore.init();

  // deploy and initialize DLogosBacker
  const trustedForwarder = "0x92371F3c1Bda1fB4F67a7984FDa54d60b0e6c6Ef"; // random address
  const dLogosBackerF = await ethers.getContractFactory("DLogosBacker");
  const dLogosBackerProxy = await upgrades.deployProxy(
    dLogosBackerF,
    [
      trustedForwarder,
      await dLogosCore.getAddress()
    ]
  );
  const dLogosBacker = dLogosBackerF.attach(await dLogosBackerProxy.getAddress());

  return {
    deployer,
    backer1,
    referrer1,

    dLogosCore,

    dLogosBackerF,
    dLogosBackerProxy,
    dLogosBacker,
    trustedForwarder
  };
};

async function prepEnvWithCrowdfund() {
  const prevEnv = await loadFixture(prepEnv);

  const crowdfundTx = await prevEnv.dLogosBacker
    .connect(prevEnv.backer1)
    .crowdfund(
      1, // logo id
      prevEnv.referrer1.address, // referrer address
      {
        value: BIGINT_1E14,
      }
    );

  return {
    ...prevEnv,

    crowdfundTx,
  }
};

async function prepEnvWithWithdrawFunds() {
  const prevEnv = await loadFixture(prepEnvWithCrowdfund);

  const withdrawFundsTx = await prevEnv.dLogosBacker
    .connect(prevEnv.backer1)
    .withdrawFunds(1);

  return {
    ...prevEnv,

    withdrawFundsTx
  };
}
