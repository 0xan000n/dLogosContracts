import {
  ethers,
  upgrades
} from "hardhat";
import {
  loadFixture,
  time,
  setBalance
} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import {
  ZERO_ADDRESS,
  BIGINT_1E15,
  BIGINT_1E14,
  BIGINT_1E13,
  BIGINT_1E12,
  ONE_DAY,
  PERCENTAGE_SCALE,
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

      it("Should revert when {_title} param is empty string", async () => {
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

      it("Should revert when {_crowdfundNumberOfDays} param > {maxDuration}", async () => {
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

      describe("Should revert when fee exceeded", () => {
        it("when proposer is zero fee", async () => {
          const env = await loadFixture(prepEnvWithCreateLogo);

          await expect(
            env.dLogosCore
              .connect(env.proposer1)
              .createLogo(
                PERCENTAGE_SCALE - await env.dLogosOwner.communityFee() + 1n,
                env.logo1Title,
                env.logo1CrowdfundNumberOfDays,
              )
          ).to.be.revertedWithCustomError(
            env.dLogosCore,
            "FeeExceeded()"
          );
        });

        it("when proposer is not zero fee", async () => {
          const env = await loadFixture(prepEnvWithCreateLogo);

          await expect(
            env.dLogosCore
              .connect(env.nonDeployer)
              .createLogo(
                PERCENTAGE_SCALE - await env.dLogosOwner.dLogosFee() - await env.dLogosOwner.communityFee() + 1n,
                env.logo1Title,
                env.logo1CrowdfundNumberOfDays,
              )
          ).to.be.revertedWithCustomError(
            env.dLogosCore,
            "FeeExceeded()"
          );
        });
      });
    });
  });

  describe("{toggleCrowdfund}, {getLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await prepEnvWithToggleCrowdfund(
        await loadFixture(prepEnvWithCreateLogo)
      );

      const logo1 = await env.dLogosCore.getLogo(1);
      expect(logo1.status.isCrowdfunding).equals(
        false
      );
    });

    it("Should emit event", async () => {
      const env = await prepEnvWithToggleCrowdfund(
        await loadFixture(prepEnvWithCreateLogo)
      );

      await expect(env.toggleCrowdfundTx)
        .emit(env.dLogosCore, "CrowdfundToggled")
        .withArgs(
          env.proposer1.address,
          false,
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await prepEnvWithToggleCrowdfund(
          await loadFixture(prepEnvWithCreateLogo)
        );

        const env1 = await prepEnvWithPauseOrUnpauseTrue(env);

        await expect(
          env1.dLogosCore
            .connect(env1.proposer1)
            .toggleCrowdfund(
              1,
            )
        ).to.be.revertedWithCustomError(
          env1.dLogosCore,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo id is not valid", async () => {
        const env = await prepEnvWithToggleCrowdfund(
          await loadFixture(prepEnvWithCreateLogo)
        );

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .toggleCrowdfund(
              2,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidLogoId()"
        );
      });

      it("Should revert when caller is not proposer", async () => {
        const env = await prepEnvWithToggleCrowdfund(
          await loadFixture(prepEnvWithCreateLogo)
        );

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .toggleCrowdfund(
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "Unauthorized()"
        );
      });

      it("Should revert when logo is scheduled", async () => {
        const env = await prepEnvWithToggleCrowdfund(
          await loadFixture(prepEnvWithCreateLogo)
        );

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .toggleCrowdfund(
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "Unauthorized()"
        );
      });

      it("Should revert when logo crowdfund deadline is passed", async () => {
        const env = await prepEnvWithToggleCrowdfund(
          await loadFixture(prepEnvWithCreateLogo)
        );

        await time.increase(env.logo1CrowdfundNumberOfDays * ONE_DAY);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .toggleCrowdfund(
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "CrowdfundEnded()"
        );
      });
    });
  });

  describe("{setMinimumPledge}, {getLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSetMinimumPledge);

      const logo1 = await env.dLogosCore.getLogo(1);
      expect(logo1.minimumPledge).equals(
        env.minimumPledge
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithSetMinimumPledge);

      await expect(env.setMinimumPledgeTx)
        .emit(env.dLogosCore, "MinimumPledgeSet")
        .withArgs(
          env.proposer1.address,
          env.minimumPledge,
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await loadFixture(prepEnvWithSetMinimumPledge);

        const env1 = await prepEnvWithPauseOrUnpauseTrue(env);

        await expect(
          env1.dLogosCore
            .connect(env1.proposer1)
            .setMinimumPledge(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env1.dLogosCore,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo id is not valid", async () => {
        const env = await loadFixture(prepEnvWithSetMinimumPledge);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMinimumPledge(
              2,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidLogoId()"
        );
      });

      it("Should revert when caller is not proposer", async () => {
        const env = await loadFixture(prepEnvWithSetMinimumPledge);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .setMinimumPledge(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "Unauthorized()"
        );
      });

      it("Should revert when logo is not crowdfunding", async () => {
        const env = await prepEnvWithToggleCrowdfund(
          await loadFixture(prepEnvWithSetMinimumPledge)
        );

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMinimumPledge(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoNotCrowdfunding()"
        );
      });

      it("Should revert when logo crowdfund deadline is passed", async () => {
        const env = await loadFixture(prepEnvWithSetMinimumPledge);

        await time.increase(env.logo1CrowdfundNumberOfDays * ONE_DAY);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMinimumPledge(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "CrowdfundEnded()"
        );
      });

      it("Should revert when param {_minimumPledge} is 0", async () => {
        const env = await loadFixture(prepEnvWithSetMinimumPledge);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMinimumPledge(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "NotZero()"
        );
      });
    });
  });

  describe("{refund}, {getLogo} function", () => {
    describe("Should make changes to the storage", () => {
      it("proposer can call anytime", async () => {
        const env = await loadFixture(prepEnvWithRefundCond1);

        const logo1 = await env.dLogosCore.getLogo(1);
        expect(logo1.status.isRefunded).equals(
          true
        );
      });

      it("everybody can call when logo crowdfund deadline is passed", async () => {
        const env = await loadFixture(prepEnvWithRefundCond2);

        const logo1 = await env.dLogosCore.getLogo(1);
        expect(logo1.status.isRefunded).equals(
          true
        );
      });

      it("everybody can call when {rejectionWindow} days passed since schedule date and no asset was uploaded", async () => {
        const env = await loadFixture(prepEnvWithRefundCond3);

        const logo1 = await env.dLogosCore.getLogo(1);
        expect(logo1.status.isRefunded).equals(
          true
        );
      });

      it("everybody can call when {logoRejectedFunds} exceed {rejectThreshold}", async () => {
        const env = await loadFixture(prepEnvWithRefundCond4);

        const logo1 = await env.dLogosCore.getLogo(1);
        expect(logo1.status.isRefunded).equals(
          true
        );
      });
    });

    it("Should emit event", async () => {
      // condition 1
      const env1 = await loadFixture(prepEnvWithRefundCond1);

      await expect(env1.refundTx)
        .emit(env1.dLogosCore, "RefundInitiated")
        .withArgs(
          1,
          true,
          false,
          false,
          true, // because of owner mock
        );

      // condition 2
      const env2 = await loadFixture(prepEnvWithRefundCond2);

      await expect(env2.refundTx)
        .emit(env2.dLogosCore, "RefundInitiated")
        .withArgs(
          1,
          false,
          true,
          false,
          true, // because of owner mock
        );

      // condition 3
      const env3 = await loadFixture(prepEnvWithRefundCond3);

      await expect(env3.refundTx)
        .emit(env3.dLogosCore, "RefundInitiated")
        .withArgs(
          1,
          false,
          false,
          true,
          true, // because of owner mock
        );

      // condition 4
      const env4 = await loadFixture(prepEnvWithRefundCond4);

      await expect(env4.refundTx)
        .emit(env4.dLogosCore, "RefundInitiated")
        .withArgs(
          1,
          false,
          false,
          false,
          true, // because of owner mock
        );

    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await loadFixture(prepEnvWithRefundCond1);

        const env1 = await prepEnvWithPauseOrUnpauseTrue(env);

        await expect(
          env1.dLogosCore
            .connect(env1.proposer1)
            .refund(
              1,
            )
        ).to.be.revertedWithCustomError(
          env1.dLogosCore,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo id is not valid", async () => {
        const env = await loadFixture(prepEnvWithRefundCond1);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .refund(
              2
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidLogoId()"
        );
      });

      it("Should revert when logo is distributed", async () => {
        const env = await loadFixture(prepEnvWithDistributeRewards);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .refund(
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoDistributed()"
        );
      });

      it("Should revert when logo is refunded", async () => {
        const env = await loadFixture(prepEnvWithRefundCond1);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .refund(
              1
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoRefunded()"
        );
      });
    });
  });

  describe("{setSpeakers}, {getSpeakersForLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSetSpeakers);

      const speakers = await env.dLogosCore.getSpeakersForLogo(1);
      // speaker1
      expect(speakers[0].addr).equals(
        env.speaker1.address
      );
      expect(speakers[0].fee).equals(
        env.speaker1Fee
      );
      expect(speakers[0].provider).equals(
        env.speakerProvider
      );
      expect(speakers[0].handle).equals(
        env.speaker1Handle
      );
      expect(speakers[0].status).equals(
        0
      );
      // speaker2
      expect(speakers[1].addr).equals(
        env.speaker2.address
      );
      expect(speakers[1].fee).equals(
        env.speaker2Fee
      );
      expect(speakers[1].provider).equals(
        env.speakerProvider
      );
      expect(speakers[1].handle).equals(
        env.speaker2Handle
      );
      expect(speakers[1].status).equals(
        0
      );
      // speaker3
      expect(speakers[2].addr).equals(
        env.speaker3.address
      );
      expect(speakers[2].fee).equals(
        env.speaker3Fee
      );
      expect(speakers[2].provider).equals(
        env.speakerProvider
      );
      expect(speakers[2].handle).equals(
        env.speaker3Handle
      );
      expect(speakers[2].status).equals(
        0
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithSetSpeakers);

      await expect(env.setSpeakersTx)
        .emit(env.dLogosCore, "SpeakersSet")
        .withArgs(
          env.proposer1.address,
          [
            env.speaker1.address,
            env.speaker2.address,
            env.speaker3.address,
          ],
          [
            env.speaker1Fee,
            env.speaker2Fee,
            env.speaker3Fee,
          ],
          [
            env.speakerProvider,
            env.speakerProvider,
            env.speakerProvider,
          ],
          [
            env.speaker1Handle,
            env.speaker2Handle,
            env.speaker3Handle,
          ],
        );
    });

    describe("Reverts", () => {
      const dummyParam = [
        1,
        [
          ZERO_ADDRESS,
        ],
        [
          0
        ],
        [
          "",
        ],
        [
          "",
        ],
      ];
      const emptyParam = [
        1,
        [],
        [],
        [],
        [],
      ];

      it("Should revert when contract is paused", async () => {
        const env = await prepEnvWithPauseOrUnpauseTrue(
          await loadFixture(prepEnvWithSetSpeakers)
        );

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setSpeakers(dummyParam)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo id is not valid", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakers);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setSpeakers(dummyParam.toSpliced(0, 1, 2))
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidLogoId()"
        );
      });

      it("Should revert when caller is not proposer", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakers);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .setSpeakers(dummyParam)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "Unauthorized()"
        );
      });

      it("Should revert when logo is not crowdfunding", async () => {
        const env = await prepEnvWithToggleCrowdfund(
          await loadFixture(prepEnvWithSetSpeakers)
        );

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setSpeakers(dummyParam)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoNotCrowdfunding()"
        );
      });

      it("Should revert when logo crowdfund deadline is passed", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakers);

        await time.increase(env.logo1CrowdfundNumberOfDays * ONE_DAY);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setSpeakers(dummyParam)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "CrowdfundEnded()"
        );
      });

      it("Should revert when param length is 0 or >= 100", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakers);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setSpeakers(emptyParam)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidSpeakerNumber()"
        );
      });

      it("Should revert when param array length mismtach", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakers);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setSpeakers(dummyParam.toSpliced(1, 1, [ZERO_ADDRESS, ZERO_ADDRESS]))
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidArrayArguments()"
        );
      });

      it("Should revert when fee sum is invalid", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakers);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setSpeakers(
              [
                1,
                [
                  env.speaker1.address,
                  env.speaker2.address,
                  env.speaker3.address,
                ],
                [
                  env.speaker1Fee,
                  env.speaker2Fee,
                  env.speaker3Fee + 1n,
                ],
                [
                  env.speakerProvider,
                  env.speakerProvider,
                  env.speakerProvider,
                ],
                [
                  env.speaker1Handle,
                  env.speaker2Handle,
                  env.speaker3Handle,
                ],
              ]
            )).to.be.revertedWithCustomError(
              env.dLogosCore,
              "FeeSumNotMatch()"
            );
      });
    });
  });

  describe("{setSpeakerStatus}, {getSpeakersForLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSetSpeakerStatus);

      const speakers = await env.dLogosCore.getSpeakersForLogo(1);
      // speaker1
      expect(speakers[0].status).equals(
        1,
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithSetSpeakerStatus);

      await expect(env.setSpeakerStatusTx)
        .emit(env.dLogosCore, "SpeakerStatusSet")
        .withArgs(
          1,
          env.speaker1.address,
          1
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await prepEnvWithPauseOrUnpauseTrue(
          await loadFixture(prepEnvWithSetSpeakerStatus)
        );

        await expect(
          env.dLogosCore
            .connect(env.speaker1)
            .setSpeakerStatus(
              1,
              0
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo id is not valid", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakerStatus);

        await expect(
          env.dLogosCore
            .connect(env.speaker1)
            .setSpeakerStatus(
              2,
              0
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidLogoId()"
        );
      });

      it("Should revert when param {_speakerStatus} is 0", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakerStatus);

        await expect(
          env.dLogosCore
            .connect(env.speaker1)
            .setSpeakerStatus(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidSpeakerStatus()"
        );
      });

      it("Should revert when logo is not crowdfunding", async () => {
        const env = await prepEnvWithToggleCrowdfund(
          await loadFixture(prepEnvWithSetSpeakerStatus)
        );

        await expect(
          env.dLogosCore
            .connect(env.speaker1)
            .setSpeakerStatus(
              1,
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoNotCrowdfunding()"
        );
      });

      it("Should revert when logo crowdfund deadline is passed", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakerStatus);

        await time.increase(env.logo1CrowdfundNumberOfDays * ONE_DAY);

        await expect(
          env.dLogosCore
            .connect(env.speaker1)
            .setSpeakerStatus(
              1,
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "CrowdfundEnded()"
        );
      });

      it("Should revert when caller is not speaker", async () => {
        const env = await loadFixture(prepEnvWithSetSpeakerStatus);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setSpeakerStatus(
              1,
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "Unauthorized()"
        );
      });
    });
  });

  describe("{setDate}, {getLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSetDate);

      const logo = await env.dLogosCore.getLogo(1);
      expect(logo.scheduledAt).equals(
        env.logo1ScheduledAt,
      );
      expect(logo.status.isCrowdfunding).equals(
        false,
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithSetDate);

      await expect(env.setDateTx)
        .emit(env.dLogosCore, "DateSet")
        .withArgs(
          env.proposer1.address,
          env.logo1ScheduledAt,
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await prepEnvWithPauseOrUnpauseTrue(
          await loadFixture(prepEnvWithSetDate)
        );

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setDate(
              1,
              0
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo id is not valid", async () => {
        const env = await loadFixture(prepEnvWithSetDate);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setDate(
              2,
              0
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidLogoId()"
        );
      });

      it("Should revert when caller is not proposer", async () => {
        const env = await loadFixture(prepEnvWithSetDate);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .setDate(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "Unauthorized()"
        );
      });

      it("Should revert when logo is uploaded", async () => {
        const env = await loadFixture(prepEnvWithSetMediaAsset);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setDate(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoUploaded()"
        );
      });

      it("Should revert when logo is refunded", async () => {
        const env = await loadFixture(prepEnvWithRefundCond1);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setDate(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoRefunded()"
        );
      });

      it("Should revert when logo crowdfund deadline is passed", async () => {
        const env = await loadFixture(prepEnvWithSetDate);

        await time.increase(env.logo1CrowdfundNumberOfDays * ONE_DAY);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setDate(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "CrowdfundEnded()"
        );
      });

      it("Should revert when param {_scheduledAt} <= {block.timestamp}", async () => {
        const env = await loadFixture(prepEnvWithSetDate);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setDate(
              1,
              0,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidScheduleTime()"
        );
      });
    });
  });

  describe("{setMediaAsset}, {getLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSetMediaAsset);

      const logo = await env.dLogosCore.getLogo(1);
      expect(logo.mediaAssetURL).equals(
        env.logo1MediaAssetURL,
      );
      expect(logo.status.isUploaded).equals(
        true,
      );
      expect(logo.rejectionDeadline).equals(
        BigInt(await time.latest()) + await env.dLogosOwner.rejectionWindow() * ONE_DAY,
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithSetMediaAsset);

      await expect(env.setMediaAssetTx)
        .emit(env.dLogosCore, "MediaAssetSet")
        .withArgs(
          env.proposer1.address,
          env.logo1MediaAssetURL,
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await prepEnvWithPauseOrUnpauseTrue(
          await loadFixture(prepEnvWithSetMediaAsset)
        );

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMediaAsset(
              1,
              "",
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo id is not valid", async () => {
        const env = await loadFixture(prepEnvWithSetMediaAsset);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMediaAsset(
              2,
              "",
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidLogoId()"
        );
      });

      it("Should revert when caller is not proposer", async () => {
        const env = await loadFixture(prepEnvWithSetMediaAsset);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .setMediaAsset(
              1,
              "",
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "Unauthorized()"
        );
      });

      it("Should revert when logo is distributed", async () => {
        const env = await loadFixture(prepEnvWithDistributeRewards);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMediaAsset(
              1,
              "",
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoDistributed()"
        );
      });

      it("Should revert when logo is refunded", async () => {
        const env = await loadFixture(prepEnvWithRefundCond1);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMediaAsset(
              1,
              "",
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoRefunded()",
        );
      });

      it("Should revert when logo crowdfund deadline is passed", async () => {
        const env = await loadFixture(prepEnvWithSetMediaAsset);

        await time.increase(env.logo1CrowdfundNumberOfDays * ONE_DAY);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMediaAsset(
              1,
              "",
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "CrowdfundEnded()"
        );
      });

      it("Should revert when logo's {scheduledAt} is 0", async () => {
        const env = await loadFixture(prepEnvWithCreateLogo);

        await expect(
          env.dLogosCore
            .connect(env.proposer1)
            .setMediaAsset(
              1,
              "",
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoNotScheduled()"
        );
      });

      // mainnet
      // it("Should revert when logo's {scheduledAt} is not passed", async () => {
      //   const env = await loadFixture(prepEnvWithSetMediaAsset);

      //   await expect(
      //     env.dLogosCore
      //       .connect(env.proposer1)
      //       .setMediaAsset(
      //         1,
      //         "",
      //       )
      //   ).to.be.revertedWithCustomError(
      //     env.dLogosCore,
      //     "ConvoNotHappened()"
      //   );
      // });
    });
  });

  describe("{distributeRewards}, {getLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithDistributeRewards);

      const logo1 = await env.dLogosCore.getLogo(1);
      const splitForSpeaker = logo1.splitForSpeaker;
      const splitForAffiliate = logo1.splitForAffiliate;

      // check storage
      expect(logo1.status.isDistributed).equals(
        true
      );

      // check core and splits balance
      expect(await ethers.provider.getBalance(await env.dLogosCore.getAddress())).equals(
        0
      );
      expect(await ethers.provider.getBalance(splitForSpeaker)).equals(
        5
      );
      expect(await ethers.provider.getBalance(splitForAffiliate)).equals(
        2
      );

      // check speaker balance
      expect(await ethers.provider.getBalance(env.speaker1.address)).equals(
        env.speaker1Bal + BigInt("284999999999999")
      );
      expect(await ethers.provider.getBalance(env.speaker2.address)).equals(
        env.speaker2Bal + BigInt("284999999999999")
      );
      expect(await ethers.provider.getBalance(env.speaker3.address)).equals(
        env.speaker3Bal + BigInt("189999999999999")
      );

      // check proposer balance
      expect(await ethers.provider.getBalance(env.proposer1.address)).equals(
        env.proposerBal + BigInt("94999999999999")
      );

      // check referrer balance
      const backers = await env.dLogosBacker.getBackersForLogo(1);
      expect(await ethers.provider.getBalance(env.referrer1.address)).equals(
        env.referrer1Bal + BigInt("4999999999999")
      );
      expect(await ethers.provider.getBalance(env.referrer2.address)).equals(
        env.referrer2Bal + BigInt("44999999999999")
      );
      expect(await ethers.provider.getBalance(env.community.address)).equals(
        env.communityBal + BigInt("94999999999999")
      );

      // check warehouse balance
      expect(await ethers.provider.getBalance(env.splitWarehouse)).equals(
        env.warehouseBal
      );
    });

    it("Estimate gas fee", async () => {
      const env = await loadFixture(prepEnvWithDistributeRewards);

      console.log(
        "DistributeRewards gas fee:",
        (env.callerBal - await ethers.provider.getBalance(env.nonDeployer.address)) / env.distributeRewardsTx.gasPrice
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithDistributeRewards);

      const logo1 = await env.dLogosCore.getLogo(1);
      const splitForSpeaker = logo1.splitForSpeaker;
      const splitForAffiliate = logo1.splitForAffiliate;

      await expect(env.distributeRewardsTx)
        .emit(env.dLogosCore, "RewardsDistributed")
        .withArgs(
          env.nonDeployer.address,
          splitForSpeaker,
          splitForAffiliate,
          BIGINT_1E15
        );
    });

    describe("Reverts", () => {
      it("Should revert when contract is paused", async () => {
        const env = await prepEnvWithPauseOrUnpauseTrue(
          await loadFixture(prepEnvWithDistributeRewards)
        );

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .distributeRewards(
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "EnforcedPause()"
        );
      });

      it("Should revert when logo id is not valid", async () => {
        const env = await loadFixture(prepEnvWithDistributeRewards);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .distributeRewards(
              2
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "InvalidLogoId()"
        );
      });

      it("Should revert when logo is distributed", async () => {
        const env = await loadFixture(prepEnvWithDistributeRewards);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .distributeRewards(
              1
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoDistributed()"
        );
      });

      it("Should revert when logo is refunded", async () => {
        const env = await loadFixture(prepEnvWithRefundCond1);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .distributeRewards(
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoRefunded()",
        );
      });

      it("Should revert when logo is not uploaded", async () => {
        const env = await loadFixture(prepEnvWithCreateLogo);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .distributeRewards(
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "LogoNotUploaded()",
        );
      });

      it("Should revert when logo rejection deadline is not passed", async () => {
        const env = await loadFixture(prepEnvWithSetMediaAsset);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .distributeRewards(
              1,
            )
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "RejectionDeadlineNotPassed()"
        );
      });
    });
  });

  describe("{pauseOrUnpause(true)} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

      expect(await env.dLogosCore.paused()).equals(
        true
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

      await expect(env.pauseTx)
        .emit(env.dLogosCore, "Paused")
        .withArgs(
          env.deployer.address
        );
    });

    describe("Reverts", async () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .pauseOrUnpause(true)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "OwnableUnauthorizedAccount"
        ).withArgs(
          env.nonDeployer.address
        );
      });

      it("Should revert when contract is paused", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

        await expect(
          env.dLogosCore
            .connect(env.deployer)
            .pauseOrUnpause(true)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "EnforcedPause()"
        );
      });
    });
  });

  describe("{pauseOrUnpause(false)} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

      expect(await env.dLogosCore.paused()).equals(
        false
      );
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

      await expect(env.unpauseTx)
        .emit(env.dLogosCore, "Unpaused")
        .withArgs(
          env.deployer.address
        );
    });

    describe("Reverts", async () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

        await expect(
          env.dLogosCore
            .connect(env.nonDeployer)
            .pauseOrUnpause(false)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
          "OwnableUnauthorizedAccount"
        ).withArgs(
          env.nonDeployer.address
        );
      });

      it("Should revert when contract is not paused", async () => {
        const env = await loadFixture(prepEnvWithPauseOrUnpauseFalse);

        await expect(
          env.dLogosCore
            .connect(env.deployer)
            .pauseOrUnpause(false)
        ).to.be.revertedWithCustomError(
          env.dLogosCore,
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
    proposer1,
    speaker1,
    speaker2,
    speaker3,
    referrer1,
    referrer2,
    community,
    ...otherSigners
  ] = await ethers.getSigners();

  // deploy and init DLogosOwner mock
  const dLogosOwnerF = await ethers.getContractFactory("DLogosOwnerMock");
  const dLogosOwner = await dLogosOwnerF.deploy();
  await dLogosOwner.setCommunity(community.address);

  // make proposer1 zero fee
  await dLogosOwner.setZeroFeeProposer(
    await proposer1.getAddress(),
    true
  );

  // deploy and init DLogosBacker mock
  const dLogosBackerF = await ethers.getContractFactory("DLogosBackerMock");
  const dLogosBacker = await dLogosBackerF.deploy();
  await dLogosBacker.setReferrers(
    referrer1.address,
    referrer2.address
  );

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

  // set balance of dLogosCore contract
  await setBalance(await dLogosCore.getAddress(), BIGINT_1E15);

  return {
    deployer,
    nonDeployer,
    proposer1,
    speaker1,
    speaker2,
    speaker3,
    referrer1,
    referrer2,
    community,

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
  const logo1CrowdfundNumberOfDays = 40n;
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

async function prepEnvWithToggleCrowdfund(prevEnv?: any) {
  if (prevEnv == undefined) {
    prevEnv = await loadFixture(prepEnv);
  }

  const toggleCrowdfundTx = await prevEnv.dLogosCore
    .connect(prevEnv.proposer1)
    .toggleCrowdfund(
      1
    );

  return {
    ...prevEnv,

    toggleCrowdfundTx,
  };
};

async function prepEnvWithSetMinimumPledge() {
  const prevEnv = await loadFixture(prepEnvWithCreateLogo);

  const minimumPledge = BIGINT_1E14;
  const setMinimumPledgeTx = await prevEnv.dLogosCore
    .connect(prevEnv.proposer1)
    .setMinimumPledge(
      1,
      minimumPledge,
    );

  return {
    ...prevEnv,

    minimumPledge,
    setMinimumPledgeTx,
  };
};

async function prepEnvWithRefundCond1() {
  const prevEnv = await loadFixture(prepEnvWithCreateLogo);

  const refundTx = await prevEnv.dLogosCore
    .connect(prevEnv.proposer1)
    .refund(
      1
    );

  return {
    ...prevEnv,

    refundTx,
  }
}

async function prepEnvWithRefundCond2() {
  const prevEnv = await loadFixture(prepEnvWithCreateLogo);

  await time.increase(prevEnv.logo1CrowdfundNumberOfDays * ONE_DAY);
  const refundTx = await prevEnv.dLogosCore
    .connect(prevEnv.nonDeployer)
    .refund(
      1
    );

  return {
    ...prevEnv,

    refundTx,
  }
}

async function prepEnvWithRefundCond3() {
  const prevEnv = await loadFixture(prepEnvWithSetDate);

  await time.increaseTo(prevEnv.logo1ScheduledAt + await prevEnv.dLogosOwner.rejectionWindow() * ONE_DAY);
  const refundTx = await prevEnv.dLogosCore
    .connect(prevEnv.nonDeployer)
    .refund(
      1
    );

  return {
    ...prevEnv,

    refundTx,
  }
}

async function prepEnvWithRefundCond4() {
  const prevEnv = await loadFixture(prepEnvWithCreateLogo);

  const refundTx = await prevEnv.dLogosCore
    .connect(prevEnv.nonDeployer)
    .refund(
      1
    );

  return {
    ...prevEnv,

    refundTx,
  }
}

async function prepEnvWithSetSpeakers() {
  const prevEnv = await loadFixture(prepEnvWithCreateLogo);

  const speaker1Fee = 300000n; // 30%
  const speaker2Fee = 300000n; // 30%
  const speaker3Fee = 200000n; // 20%
  const speakerProvider = "x.com";
  const speaker1Handle = "@Speaker1";
  const speaker2Handle = "@Speaker2";
  const speaker3Handle = "@Speaker3";
  const setSpeakersTx = await prevEnv.dLogosCore
    .connect(prevEnv.proposer1)
    .setSpeakers(
      [
        1,
        [
          prevEnv.speaker1.address,
          prevEnv.speaker2.address,
          prevEnv.speaker3.address,
        ],
        [
          speaker1Fee,
          speaker2Fee,
          speaker3Fee,
        ],
        [
          speakerProvider,
          speakerProvider,
          speakerProvider,
        ],
        [
          speaker1Handle,
          speaker2Handle,
          speaker3Handle,
        ],
      ]
    );

  return {
    ...prevEnv,

    speaker1Fee,
    speaker2Fee,
    speaker3Fee,
    speakerProvider,
    speaker1Handle,
    speaker2Handle,
    speaker3Handle,

    setSpeakersTx,
  };
}

async function prepEnvWithSetSpeakerStatus() {
  const prevEnv = await loadFixture(prepEnvWithSetSpeakers);

  const setSpeakerStatusTx = await prevEnv.dLogosCore
    .connect(prevEnv.speaker1)
    .setSpeakerStatus(
      1,
      1, // accepted
    );

  await prevEnv.dLogosCore
    .connect(prevEnv.speaker2)
    .setSpeakerStatus(
      1,
      1, // accepted
    );

  await prevEnv.dLogosCore
    .connect(prevEnv.speaker3)
    .setSpeakerStatus(
      1,
      1, // accepted
    );

  return {
    ...prevEnv,

    setSpeakerStatusTx,
  };
}

async function prepEnvWithSetDate() {
  const prevEnv = await loadFixture(prepEnvWithSetSpeakerStatus);

  const logo1ScheduledAt = BigInt(await time.latest()) + 10n * ONE_DAY;
  const setDateTx = await prevEnv.dLogosCore
    .connect(prevEnv.proposer1)
    .setDate(
      1,
      logo1ScheduledAt,
    );

  return {
    ...prevEnv,

    logo1ScheduledAt,
    setDateTx,
  };
}

async function prepEnvWithSetMediaAsset() {
  const prevEnv = await loadFixture(prepEnvWithSetDate);

  // increase time for mainnet
  // await time.increaseTo(prevEnv.logo1ScheduledAt);

  const logo1MediaAssetURL = "http://dlogos.com/assets/1";
  const setMediaAssetTx = await prevEnv.dLogosCore
    .connect(prevEnv.proposer1)
    .setMediaAsset(
      1,
      logo1MediaAssetURL,
    );

  return {
    ...prevEnv,

    logo1MediaAssetURL,
    setMediaAssetTx,
  };
}

async function prepEnvWithDistributeRewards() {
  const prevEnv = await loadFixture(prepEnvWithSetMediaAsset);

  // increase time
  const logo1RejectionDeadline = (await prevEnv.dLogosCore.getLogo(1)).rejectionDeadline;
  await time.increaseTo(logo1RejectionDeadline);

  // balance
  const splitWarehouse = "0x8fb66F38cF86A3d5e8768f8F1754A24A6c661Fb8";
  const proposerBal = await ethers.provider.getBalance(prevEnv.proposer1.address);
  const speaker1Bal = await ethers.provider.getBalance(prevEnv.speaker1.address);
  const speaker2Bal = await ethers.provider.getBalance(prevEnv.speaker2.address);
  const speaker3Bal = await ethers.provider.getBalance(prevEnv.speaker3.address);
  const referrer1Bal = await ethers.provider.getBalance(prevEnv.referrer1.address);
  const referrer2Bal = await ethers.provider.getBalance(prevEnv.referrer2.address);
  const warehouseBal = await ethers.provider.getBalance(splitWarehouse);
  const communityBal = await ethers.provider.getBalance(prevEnv.community.address);
  const callerBal = await ethers.provider.getBalance(prevEnv.nonDeployer.address);

  const distributeRewardsTx = await prevEnv.dLogosCore
    .connect(prevEnv.nonDeployer)
    .distributeRewards(
      1
    );

  return {
    ...prevEnv,

    splitWarehouse,
    proposerBal,
    speaker1Bal,
    speaker2Bal,
    speaker3Bal,
    warehouseBal,
    referrer1Bal,
    referrer2Bal,
    communityBal,
    callerBal,

    distributeRewardsTx,
  };
}

async function prepEnvWithPauseOrUnpauseFalse() {
  const prevEnv = await loadFixture(prepEnvWithPauseOrUnpauseTrue);

  const unpauseTx = await prevEnv.dLogosCore
    .connect(prevEnv.deployer)
    .pauseOrUnpause(false);

  return {
    ...prevEnv,

    unpauseTx,
  };
}
