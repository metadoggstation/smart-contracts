const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("METADOGG STATION Contracts", function () {
  let owner, mechanic, driver, other, tba;
  let ChamberCartridge, chamber;
  let MetadoggLicenseSBT, sbt;

  beforeEach(async function () {
    [owner, mechanic, driver, other, tba] = await ethers.getSigners();

    ChamberCartridge = await ethers.getContractFactory("ChamberCartridge");
    chamber = await ChamberCartridge.deploy();

    MetadoggLicenseSBT = await ethers.getContractFactory("MetadoggLicenseSBT");
    sbt = await MetadoggLicenseSBT.deploy();
  });

  describe("ChamberCartridge (ERC-4907 タンデム/相乗り)", function () {
    beforeEach(async function () {
      await chamber.mintCartridge(owner.address, "ipfs://test", 80, 20);
    });

    it("オーナーがUserと有効期限を設定でき、期限前はuserOfがUserを返す", async function () {
      const expiresAt = (await time.latest()) + 3600;

      await expect(chamber.connect(owner).setUser(0, driver.address, expiresAt))
        .to.emit(chamber, "UpdateUser")
        .withArgs(0, driver.address, expiresAt);

      expect(await chamber.userOf(0)).to.equal(driver.address);
      expect(await chamber.userExpires(0)).to.equal(expiresAt);
    });

    it("有効期限を過ぎるとuserOfがゼロアドレスを返す", async function () {
      const expiresAt = (await time.latest()) + 3600;
      await chamber.connect(owner).setUser(0, driver.address, expiresAt);

      await time.increaseTo(expiresAt + 1);

      expect(await chamber.userOf(0)).to.equal(ethers.ZeroAddress);
    });

    it("オーナー以外がsetUserを呼び出すとRevertする", async function () {
      const expiresAt = (await time.latest()) + 3600;

      await expect(
        chamber.connect(mechanic).setUser(0, driver.address, expiresAt)
      ).to.be.revertedWith("Not authorized");
    });
  });

  describe("MetadoggLicenseSBT (ERC-5192 通行手形)", function () {
    it("オーナーが指定したTBAへSBTを発行し、Lockedイベントを発火する", async function () {
      await expect(sbt.connect(owner).issueLicense(tba.address))
        .to.emit(sbt, "Locked")
        .withArgs(0);

      expect(await sbt.ownerOf(0)).to.equal(tba.address);
    });

    it("MintされたSBTを別のウォレットへ転送できない", async function () {
      await sbt.connect(owner).issueLicense(driver.address);

      await expect(
        sbt.connect(driver).transferFrom(driver.address, other.address, 0)
      ).to.be.revertedWith("Err: This is a Soulbound Token");
    });
  });
});