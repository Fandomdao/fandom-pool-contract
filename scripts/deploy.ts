import { ethers } from "hardhat";

async function main() {
  const DpPool = await ethers.deployContract("DpPool");

  await DpPool.waitForDeployment();

  console.log(`DpPool contract deployed to ${DpPool.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
