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

  describe("{crowdfund}, {getBackersForLogo} function", () => {
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

        const env1 = await prepEnvWithPauseOrUnpauseTrue(env);

        await expect(
          env1.dLogosBacker
            .connect(env1.backer1)
            .crowdfund(
              0,
              ZERO_ADDRESS
            )
        ).to.be.revertedWithCustomError(
          env1.dLogosBacker,
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

  describe("{withdrawFunds}, {getBackersForLogo} function", () => {
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
      it("Should revert when contract is paused", async () => {
        const env = await loadFixture(prepEnvWithWithdrawFunds);

        const env1 = await prepEnvWithPauseOrUnpauseTrue(env);

        await expect(
          env.dLogosBacker
            .connect(env1.backer1)
            .withdrawFunds(
              0
            )
        ).to.be.revertedWithCustomError(
          env1.dLogosBacker,
          "EnforcedPause()"
        );
      });

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

      it("Should revert when logo is {isUploaded} and not {isRefunded}", async () => {
        const env = await loadFixture(prepEnvWithWithdrawFunds);

        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .withdrawFunds(
              4
            )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "LogoFundsCannotBeWithdrawn()"
        );
      });

      it("Should revert when logo is {isDistributed}", async () => {
        const env = await loadFixture(prepEnvWithWithdrawFunds);

        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .withdrawFunds(
              5
            )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "LogoFundsCannotBeWithdrawn()"
        );
      });

      it("Should revert when caller is not backer", async () => {
        const env = await loadFixture(prepEnvWithWithdrawFunds);

        await expect(
          env.dLogosBacker
            .connect(env.backer2)
            .withdrawFunds(
              1
            )
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "Unauthorized()"
        );
      });
    });
  });

  describe("{reject} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithReject);

      expect(await env.dLogosBacker.logoRejectedFunds(1)).equals(
        BIGINT_1E14
      );
      const backers = await env.dLogosBacker.getBackersForLogo(1);
      expect(backers[0].votesToReject).equals(
        true
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithReject);

      await expect(env.rejectTx)
        .emit(env.dLogosBacker, "RejectionSubmitted")
        .withArgs(
          1,
          env.backer1.address
        );
    });

    describe("Reverts", async () => {
      it("Should revert when contract is paused", async () => {
        const env = await loadFixture(prepEnvWithReject);

        const env1 = await prepEnvWithPauseOrUnpauseTrue(env);

        await expect(
          env1.dLogosBacker
            .connect(env1.backer1)
            .reject(
              0
            )
        ).to.be.revertedWithCustomError(
          env1.dLogosBacker,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo is not created", async () => {
        const env = await loadFixture(prepEnvWithReject);

        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .reject(3)
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "InvalidLogoId()"
        );
      });

      it("Should revert when logo rejection deadline passed", async () => {
        const env = await loadFixture(prepEnvWithReject);

        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .reject(2)
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "RejectionDeadlinePassed()"
        );
      });

      it("Should revert when caller is not backer", async () => {
        const env = await loadFixture(prepEnvWithReject);

        await expect(
          env.dLogosBacker
            .connect(env.backer2)
            .reject(1)
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "Unauthorized()"
        );
      });

      it("Should revert when backer tries to reject twice", async () => {
        const env = await loadFixture(prepEnvWithReject);

        await expect(
          env.dLogosBacker
            .connect(env.backer1)
            .reject(1)
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "BackerAlreadyRejected()"
        );
      });
    });
  });

  describe("{pauseOrUnpause(true)} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

      expect(await env.dLogosBacker.paused()).equals(
        true
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

      await expect(env.pauseTx)
        .emit(env.dLogosBacker, "Paused")
        .withArgs(
          env.deployer.address
        );
    });

    describe("Reverts", async () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

        await expect(
          env.dLogosBacker
            .connect(env.nonDeployer)
            .pauseOrUnpause(true)
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "OwnableUnauthorizedAccount"
        ).withArgs(
          env.nonDeployer.address
        );
      });

      it("Should revert when contract is paused", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

        await expect(
          env.dLogosBacker
            .connect(env.deployer)
            .pauseOrUnpause(true)
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "EnforcedPause()"
        );
      });
    });
  });

  describe("{pauseOrUnpause(false)} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

      expect(await env.dLogosBacker.paused()).equals(
        false
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

      await expect(env.unpauseTx)
        .emit(env.dLogosBacker, "Unpaused")
        .withArgs(
          env.deployer.address
        );
    });

    describe("Reverts", async () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

        await expect(
          env.dLogosBacker
            .connect(env.nonDeployer)
            .pauseOrUnpause(false)
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "OwnableUnauthorizedAccount"
        ).withArgs(
          env.nonDeployer.address
        );
      });

      it("Should revert when contract is not paused", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

        await expect(
          env.dLogosBacker
            .connect(env.deployer)
            .pauseOrUnpause(false)
        ).to.be.revertedWithCustomError(
          env.dLogosBacker,
          "ExpectedPause()"
        );
      });
    });
  });
});

async function prepEnv() {
  const [deployer, nonDeployer, backer1, referrer1, backer2, referrer2, ...otherSigners] = await ethers.getSigners();

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
    nonDeployer,
    backer1,
    referrer1,
    backer2,
    referrer2,

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

async function prepEnvWithReject() {
  const prevEnv = await loadFixture(prepEnvWithCrowdfund);

  // advance time by 4 days
  await time.increase(ONE_DAY * 4);

  const rejectTx = await prevEnv.dLogosBacker
    .connect(prevEnv.backer1)
    .reject(1);

  return {
    ...prevEnv,

    rejectTx,
  }
}

async function prepEnvWithPauseOrUnpauseTrue(prevEnv?: any) {
  if (prevEnv == undefined) {
    prevEnv = await loadFixture(prepEnv);
  }

  const pauseTx = await prevEnv.dLogosBacker
    .connect(prevEnv.deployer)
    .pauseOrUnpause(true);

  return {
    ...prevEnv,

    pauseTx,
  };
}

async function prepEnvWithPauseOrUnpauseFalse() {
  const prevEnv = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

  const unpauseTx = await prevEnv.dLogosBacker
    .connect(prevEnv.deployer)
    .pauseOrUnpause(false);

  return {
    ...prevEnv,

    unpauseTx,
  };
}
