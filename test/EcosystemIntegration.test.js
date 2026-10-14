const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("METADOGG STATION Ecosystem Integration", function () {
  it("オンボーディングから給油、燃料獲得までのPA進行をシミュレートする", async function () {
    const [player, trustedSigner] = await ethers.getSigners();

    const chamber = await (await ethers.getContractFactory("ChamberCartridge")).deploy();
    const meatToken = await (
      await ethers.getContractFactory("MeatToken")
    ).deploy(trustedSigner.address);
    const butcherPool = await (
      await ethers.getContractFactory("ButcherPool")
    ).deploy(await meatToken.getAddress());

    const tokenId = 0n;
    await chamber.mintCartridge(player.address, "ipfs://cartridge", 80, 20);

    const network = await ethers.provider.getNetwork();
    const cartridgeAccount = await (
      await ethers.getContractFactory("CartridgeAccount")
    ).deploy(await chamber.getAddress(), tokenId, network.chainId);
    const tbaAddress = await cartridgeAccount.getAddress();

    const stakeAmount = ethers.parseEther("10");
    const domain = {
      name: "MetadoggStation",
      version: "1",
      chainId: network.chainId,
      verifyingContract: await meatToken.getAddress(),
    };
    const types = {
      PoFReward: [
        { name: "tbaAddress", type: "address" },
        { name: "amount", type: "uint256" },
        { name: "nonce", type: "uint256" },
      ],
    };
    const reward = {
      tbaAddress,
      amount: stakeAmount,
      nonce: 0n,
    };
    const signature = await trustedSigner.signTypedData(domain, types, reward);

    await meatToken
      .connect(player)
      .claimPoFReward(tbaAddress, stakeAmount, signature);
    expect(await meatToken.balanceOf(tbaAddress)).to.equal(stakeAmount);

    const approveCall = meatToken.interface.encodeFunctionData("approve", [
      await butcherPool.getAddress(),
      stakeAmount,
    ]);
    await cartridgeAccount
      .connect(player)
      .executeCall(await meatToken.getAddress(), 0, approveCall);

    const stakeCall = butcherPool.interface.encodeFunctionData("stakeMeat", [
      stakeAmount,
    ]);
    await cartridgeAccount
      .connect(player)
      .executeCall(await butcherPool.getAddress(), 0, stakeCall);

    const stake = await butcherPool.stakes(tbaAddress);
    expect(stake.amount).to.equal(stakeAmount);
    expect(await meatToken.balanceOf(tbaAddress)).to.equal(0n);
    expect(await meatToken.balanceOf(await butcherPool.getAddress())).to.equal(
      stakeAmount
    );

    const oneDayInSeconds = 24 * 60 * 60;
    await time.increase(oneDayInSeconds);

    const expectedFuel = BigInt(oneDayInSeconds) * stakeAmount * 100n;
    expect(await butcherPool.calculatePendingFuel(tbaAddress)).to.equal(
      expectedFuel
    );
  });
});
