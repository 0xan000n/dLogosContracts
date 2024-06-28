import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import { 
  ZERO_ADDRESS,
  PERCENTAGE_SCALE,
  MAX_AFFILIATE_FEE,
} from "./_helpers/constants";

describe("DLogosOwner Tests", () => {
  it("Test prepEnv", async () => {
    const env = await loadFixture(prepEnv);

    // check ownership
    expect(await env.dLogosOwner.owner()).equals(
      env.deployer.address
    );

    // check public variables
    expect(await env.dLogosOwner.dLogos()).equals(
      env.dLogosAddress
    );
    expect(await env.dLogosOwner.community()).equals(
      env.communityAddress
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

      it("Should revert when param == 0 or param > 10000", async () => {
        const env = await loadFixture(prepEnvWithRejectThreshold);

        // 0
        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setRejectThreshold(0)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "InvalidRejectThreshold()"
        );

        // 10001
        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setRejectThreshold(10001)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "InvalidRejectThreshold()"
        );
      });
    });
  });

  describe("{setMaxDuration} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithMaxDuration);

      expect(await env.dLogosOwner.maxDuration()).equals(env.maxDuration);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithMaxDuration);

      await expect(env.setMaxDurationTx)
        .emit(env.dLogosOwner, "MaxDurationUpdated")
        .withArgs(env.maxDuration);
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithMaxDuration);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setMaxDuration(0)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
      });

      it("Should revert when param == 0 or param > 100", async () => {
        const env = await loadFixture(prepEnvWithMaxDuration);

        // 0
        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setMaxDuration(0)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "InvalidMaxDuration()"
        );

        // 101
        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setMaxDuration(101)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "InvalidMaxDuration()"
        );
      });
    });
  });

  describe("{setRejectionWindow} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithRejectionWindow);

      expect(await env.dLogosOwner.rejectionWindow()).equals(env.rejectionWindow);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithRejectionWindow);

      await expect(env.setRejectionWindowTx)
        .emit(env.dLogosOwner, "RejectionWindowUpdated")
        .withArgs(env.rejectionWindow);
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithRejectionWindow);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setRejectionWindow(0)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
      });
    });
  });

  describe("{setDLogosAddress} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithDLogosAddress);

      expect(await env.dLogosOwner.dLogos()).equals(env.dLogosAddress);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithDLogosAddress);

      await expect(env.setDLogosAddressTx)
        .emit(env.dLogosOwner, "DLogosAddressUpdated")
        .withArgs(env.dLogosAddress);
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithDLogosAddress);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setDLogosAddress(ZERO_ADDRESS)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
      });

      it("Should revert when param is zero address", async () => {
        const env = await loadFixture(prepEnvWithDLogosAddress);

        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setDLogosAddress(ZERO_ADDRESS)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "ZeroAddress()"
        );
      });
    });
  });

  describe("{setCommunityAddress} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithCommunityAddress);

      expect(await env.dLogosOwner.community()).equals(env.communityAddress);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithCommunityAddress);

      await expect(env.setCommunityAddressTx)
        .emit(env.dLogosOwner, "CommunityAddressUpdated")
        .withArgs(env.communityAddress);
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithCommunityAddress);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setCommunityAddress(ZERO_ADDRESS)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
      });

      it("Should revert when param is zero address", async () => {
        const env = await loadFixture(prepEnvWithCommunityAddress);

        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setCommunityAddress(ZERO_ADDRESS)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "ZeroAddress()"
        );
      });
    });
  });

  describe("{setDLogosFee} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithDLogosFee);

      expect(await env.dLogosOwner.dLogosFee()).equals(env.dLogosFee);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithDLogosFee);

      await expect(env.setDLogosFeeTx)
        .emit(env.dLogosOwner, "DLogosFeeUpdated")
        .withArgs(env.dLogosFee);
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithDLogosFee);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setDLogosFee(0)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
      });

      it("Should revert when param > {PERCENTAGE_SCALE}", async () => {
        const env = await loadFixture(prepEnvWithDLogosFee);

        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setDLogosFee(PERCENTAGE_SCALE + 1n)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "FeeExceeded()"
        );
      });
    });
  });

  describe("{setCommunityFee} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithCommunityFee);

      expect(await env.dLogosOwner.communityFee()).equals(env.communityFee);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithCommunityFee);

      await expect(env.setCommunityFeeTx)
        .emit(env.dLogosOwner, "CommunityFeeUpdated")
        .withArgs(env.communityFee);
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithCommunityFee);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setCommunityFee(0)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
      });

      it("Should revert when param + {dLogosFee} > {PERCENTAGE_SCALE}", async () => {
        const env = await loadFixture(prepEnvWithCommunityFee);
        
        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setCommunityFee(PERCENTAGE_SCALE - env.dLogosFee + 1n)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "FeeExceeded()"
        );
      });
    });
  });

  describe("{setAffiliateFee} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithAffiliateFee);

      expect(await env.dLogosOwner.affiliateFee()).equals(env.affiliateFee);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithAffiliateFee);

      await expect(env.setAffiliateFeeTx)
        .emit(env.dLogosOwner, "AffiliateFeeUpdated")
        .withArgs(env.affiliateFee);
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithAffiliateFee);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setAffiliateFee(0)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
      });

      it("Should revert when param > {MAX_AFFILIATE_FEE}", async () => {
        const env = await loadFixture(prepEnvWithAffiliateFee);
        
        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setAffiliateFee(MAX_AFFILIATE_FEE + 1n)
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "FeeExceeded()"
        );
      });
    });
  });

  describe("{setZeroFeeProposers}, {isZeroFeeProposer} function", () => {
    it("Should make changes to the storage", async () => {
      const env = await loadFixture(prepEnvWithZeroFeeProposers);

      expect(await env.dLogosOwner.isZeroFeeProposer(env.proposer1Address)).equals(env.isP1ZeroFee);
      expect(await env.dLogosOwner.isZeroFeeProposer(env.proposer2Address)).equals(env.isP2ZeroFee);
    });

    it("Should emit event", async () => {
      const env = await loadFixture(prepEnvWithZeroFeeProposers);

      await expect(env.setZeroFeeProposersTx)
        .emit(env.dLogosOwner, "ZeroFeeProposersSet")
        .withArgs(
          [env.proposer1Address, env.proposer2Address],
          [env.isP1ZeroFee, env.isP2ZeroFee]
        );
    });

    describe("Reverts", () => {
      it("Should revert when not allowed user", async () => {
        const env = await loadFixture(prepEnvWithZeroFeeProposers);

        // random user
        await expect(
          env.dLogosOwner
            .connect(env.alice)
            .setZeroFeeProposers(
              [ZERO_ADDRESS],
              [true]
            )
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "OwnableUnauthorizedAccount"
        ).withArgs(env.alice.address);
      });

      it("Should revert when params' length mismtach", async () => {
        const env = await loadFixture(prepEnvWithZeroFeeProposers);
        
        await expect(
          env.dLogosOwner
            .connect(env.deployer)
            .setZeroFeeProposers(
              [ZERO_ADDRESS],
              [true, true]
            )
        ).to.be.revertedWithCustomError(
          env.dLogosOwner,
          "InvalidArrayArguments"
        );
      });
    });
  });
});

async function prepEnv() {
  const [deployer, alice, proposer1, proposer2, ...otherSigners] = await ethers.getSigners();

  const dLogosAddress = "0x039f095BD832D3D97077024f787F13C2c0139381";
  const communityAddress = "0xFE34EFdc1e537777b5d3AfF604dbAD3514502dd1";
  const dLogosOwnerF = await ethers.getContractFactory("DLogosOwner");
  const dLogosOwnerProxy = await upgrades.deployProxy(
    dLogosOwnerF,
    [
      dLogosAddress,
      communityAddress
    ],
    {
      initializer: "initialize",
    }
  );
  const dLogosOwner = dLogosOwnerF.attach(await dLogosOwnerProxy.getAddress());

  return {
    deployer,
    alice,
    proposer1Address: proposer1.address,
    proposer2Address: proposer2.address,
    
    dLogosAddress,
    communityAddress,

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

async function prepEnvWithMaxDuration() {
  const prevEnv = await loadFixture(prepEnvWithRejectThreshold);

  const maxDuration = 70;
  const setMaxDurationTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setMaxDuration(maxDuration);

  return {
    ...prevEnv,

    maxDuration,
    setMaxDurationTx,
  };
};

async function prepEnvWithRejectionWindow() {
  const prevEnv = await loadFixture(prepEnvWithMaxDuration);

  const rejectionWindow = 6;
  const setRejectionWindowTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setRejectionWindow(rejectionWindow);

  return {
    ...prevEnv,

    rejectionWindow,
    setRejectionWindowTx,
  };
};

async function prepEnvWithDLogosAddress() {
  const prevEnv = await loadFixture(prepEnvWithRejectionWindow);

  const dLogosAddress = "0xA272896E12F741c9E82C67eC702BBFF95D4004cD";
  const setDLogosAddressTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setDLogosAddress(dLogosAddress);

  return {
    ...prevEnv,

    dLogosAddress,
    setDLogosAddressTx,
  };
};

async function prepEnvWithCommunityAddress() {
  const prevEnv = await loadFixture(prepEnvWithDLogosAddress);

  const communityAddress = "0x2F6EfC44c5f00679C57FE2134f51755f9068B517";
  const setCommunityAddressTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setCommunityAddress(communityAddress);

  return {
    ...prevEnv,

    communityAddress,
    setCommunityAddressTx,
  };
};

async function prepEnvWithDLogosFee() {
  const prevEnv = await loadFixture(prepEnvWithCommunityAddress);

  const dLogosFee = 200000n; // 20%
  const setDLogosFeeTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setDLogosFee(dLogosFee);

  return {
    ...prevEnv,

    dLogosFee,
    setDLogosFeeTx,
  };
};

async function prepEnvWithCommunityFee() {
  const prevEnv = await loadFixture(prepEnvWithDLogosFee);

  const communityFee = 200000; // 20%
  const setCommunityFeeTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setCommunityFee(communityFee);

  return {
    ...prevEnv,

    communityFee,
    setCommunityFeeTx,
  };
};

async function prepEnvWithAffiliateFee() {
  const prevEnv = await loadFixture(prepEnvWithCommunityFee);

  const affiliateFee = 150000; // 15%
  const setAffiliateFeeTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setAffiliateFee(affiliateFee);

  return {
    ...prevEnv,

    affiliateFee,
    setAffiliateFeeTx,
  };
};

async function prepEnvWithZeroFeeProposers() {
  const prevEnv = await loadFixture(prepEnvWithAffiliateFee);

  const isP1ZeroFee = true;
  const isP2ZeroFee = false;
  const setZeroFeeProposersTx = await prevEnv.dLogosOwner
    .connect(prevEnv.deployer)
    .setZeroFeeProposers(
      [prevEnv.proposer1Address, prevEnv.proposer2Address],
      [isP1ZeroFee, isP2ZeroFee]
    );

  return {
    ...prevEnv,

    isP1ZeroFee,
    isP2ZeroFee,
    setZeroFeeProposersTx,
  };
};
