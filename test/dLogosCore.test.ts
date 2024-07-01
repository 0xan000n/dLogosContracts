import { ethers, upgrades } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import {
  ZERO_ADDRESS,
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
              .connect(env.proposer2)
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
            .connect(env.proposer2)
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
            .connect(env.proposer2)
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
            .connect(env.proposer2)
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

  // describe("{refund}, {getLogo} function", () => {
  //   describe("Should make changes to the storage", () => {
  //     it("proposer can call anytime", async () => {
  //       const env = await loadFixture(prepEnvWithRefundCond1);

  //       const logo1 = await env.dLogosCore.getLogo(1);
  //       expect(logo1.status.isRefunded).equals(
  //         true
  //       );
  //     });

  //     it("everybody can call when logo crowdfund deadline is passed", async () => {
  //       const env = await loadFixture(prepEnvWithRefundCond2);

  //       const logo1 = await env.dLogosCore.getLogo(1);
  //       expect(logo1.status.isRefunded).equals(
  //         true
  //       );
  //     });
  //   });

  //   it("Should emit event", async () => {
  //     const env = await loadFixture(prepEnvWithRefund);

  //     await expect(env.setMinimumPledgeTx)
  //       .emit(env.dLogosCore, "MinimumPledgeSet")
  //       .withArgs(
  //         env.proposer1.address,
  //         env.minimumPledge,
  //       );
  //   });

  //   describe("Reverts", () => {
  //     it("Should revert when contract is paused", async () => {
  //       const env = await loadFixture(prepEnvWithRefund);

  //       const env1 = await prepEnvWithPauseOrUnpauseTrue(env);

  //       await expect(
  //         env1.dLogosCore
  //           .connect(env1.proposer1)
  //           .refund(
  //             1,
  //             0,
  //           )
  //       ).to.be.revertedWithCustomError(
  //         env1.dLogosCore,
  //         "EnforcedPause()"
  //       );
  //     });

  //     it("Should revert when logo id is not valid", async () => {
  //       const env = await loadFixture(prepEnvWithRefund);

  //       await expect(
  //         env.dLogosCore
  //           .connect(env.proposer1)
  //           .refund(
  //             2,
  //             0,
  //           )
  //       ).to.be.revertedWithCustomError(
  //         env.dLogosCore,
  //         "InvalidLogoId()"
  //       );
  //     });

  //     it("Should revert when caller is not proposer", async () => {
  //       const env = await loadFixture(prepEnvWithRefund);

  //       await expect(
  //         env.dLogosCore
  //           .connect(env.proposer2)
  //           .refund(
  //             1,
  //             0,
  //           )
  //       ).to.be.revertedWithCustomError(
  //         env.dLogosCore,
  //         "Unauthorized()"
  //       );
  //     });

  //     it("Should revert when logo is not crowdfunding", async () => {
  //       const env = await prepEnvWithToggleCrowdfund(
  //         await loadFixture(prepEnvWithRefund)
  //       );

  //       await expect(
  //         env.dLogosCore
  //           .connect(env.proposer1)
  //           .refund(
  //             1,
  //             0,
  //           )
  //       ).to.be.revertedWithCustomError(
  //         env.dLogosCore,
  //         "LogoNotCrowdfunding()"
  //       );
  //     });

  //     it("Should revert when logo crowdfund deadline is passed", async () => {
  //       const env = await loadFixture(prepEnvWithRefund);

  //       await time.increase(4n * ONE_DAY);

  //       await expect(
  //         env.dLogosCore
  //           .connect(env.proposer1)
  //           .refund(
  //             1,
  //             0,
  //           )
  //       ).to.be.revertedWithCustomError(
  //         env.dLogosCore,
  //         "CrowdfundEnded()"
  //       );
  //     });

  //     it("Should revert when param {_minimumPledge} is 0", async () => {
  //       const env = await loadFixture(prepEnvWithRefund);

  //       await expect(
  //         env.dLogosCore
  //           .connect(env.proposer1)
  //           .refund(
  //             1,
  //             0,
  //           )
  //       ).to.be.revertedWithCustomError(
  //         env.dLogosCore,
  //         "NotZero()"
  //       );
  //     });
  //   });
  // });

  describe("{setSpeakers}, {getLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSetSpeakers);

      const s1 = await env.dLogosCore.logoSpeakers(1, 0);
      const s2 = await env.dLogosCore.logoSpeakers(1, 1);
      const s3 = await env.dLogosCore.logoSpeakers(1, 2);
      // speaker1
      expect(s1.addr).equals(
        env.speaker1.address
      );
      expect(s1.fee).equals(
        env.speaker1Fee
      );
      expect(s1.provider).equals(
        env.speakerProvider
      );
      expect(s1.handle).equals(
        env.speaker1Handle
      );
      expect(s1.status).equals(
        0
      );
      // speaker2
      expect(s2.addr).equals(
        env.speaker2.address
      );
      expect(s2.fee).equals(
        env.speaker2Fee
      );
      expect(s2.provider).equals(
        env.speakerProvider
      );
      expect(s2.handle).equals(
        env.speaker2Handle
      );
      expect(s2.status).equals(
        0
      );
      // speaker3
      expect(s3.addr).equals(
        env.speaker3.address
      );
      expect(s3.fee).equals(
        env.speaker3Fee
      );
      expect(s3.provider).equals(
        env.speakerProvider
      );
      expect(s3.handle).equals(
        env.speaker3Handle
      );
      expect(s3.status).equals(
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
            .connect(env.proposer2)
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

  describe("{setSpeakerStatus}, {getLogo} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithSetSpeakerStatus);

      const s1 = await env.dLogosCore.logoSpeakers(1, 0);
      // speaker1
      expect(s1.status).equals(
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
    });
  });
});

async function prepEnv() {
  const [
    deployer,
    nonDeployer,
    proposer1,
    proposer2,
    speaker1,
    speaker2,
    speaker3,
    ...otherSigners
  ] = await ethers.getSigners();

  // deploy DLogosOwner mock
  const dLogosOwnerF = await ethers.getContractFactory("DLogosOwnerMock");
  const dLogosOwner = await dLogosOwnerF.deploy();

  // make proposer1 zero fee
  await dLogosOwner.setZeroFeeProposer(
    await proposer1.getAddress(),
    true
  );

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
    proposer2,
    speaker1,
    speaker2,
    speaker3,

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
    .connect(prevEnv.proposer2)
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

  return {
    ...prevEnv,

    setSpeakerStatusTx,
  };
}
