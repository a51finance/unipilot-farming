import { deployContract } from "./utils";
import { formatEther } from "ethers/lib/utils";
import { task } from "hardhat/config";

task("deploy-stakingFactory", "Deploy staking factory contract").setAction(
  async (cliArgs, { ethers, run, network }) => {
    await run("compile");

    const signer = (await ethers.getSigners())[0];
    console.log("Signer");
    console.log("  at", signer.address);
    console.log("  ETH", formatEther(await signer.getBalance()));

    const args = {
      time: 1685002830,
    };

    console.log("Network");
    console.log("   ", network.name);
    console.log("Task Args");
    console.log(args);

    const stakingFactory = await deployContract(
      "StakingRewardsFactory",
      await ethers.getContractFactory("StakingRewardsFactory"),
      signer,
      [args.time]
    );

    await stakingFactory.deployTransaction.wait(5);

    delay(60000);

    await run("verify:verify", {
      address: stakingFactory.address,
      constructorArguments: Object.values(args),
    });
  }
);

task("deploy-stakingDualFactory", "Deploy staking factory contract").setAction(
  async (cliArgs, { ethers, run, network }) => {
    await run("compile");

    const signer = (await ethers.getSigners())[0];
    console.log("Signer");
    console.log("  at", signer.address);
    console.log("  ETH", formatEther(await signer.getBalance()));

    const args = {
      time: 1685002830,
    };

    console.log("Network");
    console.log("   ", network.name);
    console.log("Task Args");
    console.log(args);

    const stakingFactory = await deployContract(
      "StakingDualRewardsFactory",
      await ethers.getContractFactory("StakingDualRewardsFactory"),
      signer,
      [args.time]
    );

    await stakingFactory.deployTransaction.wait(5);

    delay(60000);

    await run("verify:verify", {
      address: stakingFactory.address,
      constructorArguments: Object.values(args),
    });
  }
);

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
