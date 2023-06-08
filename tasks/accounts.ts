import { deployContract } from "./utils";
import { formatEther } from "ethers/lib/utils";
import { task } from "hardhat/config";

task("deploy-Factory", "Deploy factory contract").setAction(
  async (cliArgs, { ethers, run, network }) => {
    // await run("compile");

    // const signer = (await ethers.getSigners())[0];
    // console.log("Signer");
    // console.log("  at", signer.address);
    // console.log("  ETH", formatEther(await signer.getBalance()));

    // const factory = await deployContract(
    //   "Factory",
    //   await ethers.getContractFactory("Factory"),
    //   signer
    // );

    // await factory.deployTransaction.wait(5);

    // delay(60000);

    await run("verify:verify", {
      address: "0x7dcA599eC0dA391412b8Ba6892b2b1D55EF0896B",
    });
  }
);

task("deploy-stakingFactory", "Deploy staking factory contract").setAction(
  async (cliArgs, { ethers, run, network }) => {
    await run("compile");

    const signer = (await ethers.getSigners())[0];
    console.log("Signer");
    console.log("  at", signer.address);
    console.log("  ETH", formatEther(await signer.getBalance()));

    const genesisTime = Number((Date.now() / 1000 + 900).toFixed());
    const args = {
      time: genesisTime,
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

    const genesisTime = Number((Date.now() / 1000 + 900).toFixed());
    const args = {
      time: genesisTime,
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

task("verify-stakingvault", "verifying staking vault contract").setAction(
  async (cliArgs, { ethers, run, network }) => {
    const args = {
      _owner: "0x1e3881227010c8dcdfa2f11833d3d70a00893f94",
      _rewardsDistribution: "0x7B6763729B8af1DA39AFA5Ad054D73472cAfF599",
      _rewardsToken: "0x582DaEF1F36D6009f64b74519cFD612a8467Be18",
      _stakingToken: "0x1749af477bb94cf84c942f0db69f4213959e0b12",
    };

    await run("verify:verify", {
      address: "0x73d37578a3c8cf354918F93124bf0bcd3419Ca34",
      constructorArguments: Object.values(args),
    });
  }
);

task("verify-stakingvaultDual", "verifying staking vault contract").setAction(
  async (cliArgs, { ethers, run, network }) => {
    const args = {
      _owner: "0x9de199457b5f6e4690eac92c399a0cd31b901dc3",
      _dualRewardsDistribution: "0x6cCBAAcd30DE3D48c118cd78431EB9ed12A5d4bF",
      _rewardsTokenA: "0xaa518ed3d2160ddd8ca1d5b3173c864a00c6da7c",
      _rewardsTokenB: "0xcc4f8F12a3d473035B975D7C3424eB1C4A04b903",
      _stakingToken: "0xe6D67E9D37326f24864d1a55c1533F0DCfdd2011",
    };

    await run("verify:verify", {
      address: "0xe688508ee71897d5a3a48c62bca1de3d75f8e2c7",
      constructorArguments: Object.values(args),
    });
  }
);

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}