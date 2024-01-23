import { ethers } from "hardhat";

async function main() {
  const wallet = (await ethers.getSigners())[0];

  const factoryAddress = "0x2c3E69CfB6b3cc8879598bd531e6622929e3014e";

  // DpPool contract address (implementation contract)
  const implementationAddress = "0xd20360f9cb804d34523b4EAb96602fD1D30EC9be";

  const DpPool = await ethers.getContractAt(
    "DpPool",
    implementationAddress,
    wallet
  );
  const TransparentFactory = await ethers.getContractAt(
    "TransparentFactory",
    factoryAddress,
    wallet
  );

  const initCalldata = DpPool.interface.encodeFunctionData("initialize", [
    wallet.address,
    "0xF87bD72Da7fb8aDAa4E91AaFAC4100663F4b5A7D", // Staking Token Address (Any ERC20 Token)
  ]);

  const tx = await TransparentFactory.createContract(
    implementationAddress,
    initCalldata
  );

  console.log(`DpPool contract deployed to ${tx.hash}`);

  await tx.wait();

  const receipt = await wallet.provider.getTransactionReceipt(tx.hash);

  const contractAddress = receipt?.logs[0].address;

  console.log(`DpPool contract deployed to ${contractAddress}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
