import { ethers } from "hardhat";

async function main() {
  // input your private key
  const wallet = new ethers.Wallet("TEST_PRIVATE_KEY", ethers.provider);

  // input your contract address (proxy contract)
  const contractAddress = "0xC05580256a3D1357dea4889C1364d2fbc57D632C";

  const DpPool = await ethers.getContractAt("DpPool", contractAddress, wallet);

  console.log(`DpPool isOpen: ${await DpPool.isOpen()}`);

  // base tx
  const btx = {
    gasLimit: 1000000,
    gasPrice: ethers.parseUnits("5", "gwei"),
  };

  const tx = await DpPool.stake(5n * 10n ** 18n, btx);

  console.log(`DpPool staked: ${tx.hash}`);

  await tx.wait();

  console.log(`DpPool staked: ${tx.hash}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
