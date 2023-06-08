forge script script/StakingDualRewardsFactory.s.sol:DeployStakingDualRewardsFactoryScript --fork-url "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161" --broadcast --verify -vvvv 
# forge script script/StakingDualRewardsFactory.s.sol:DeployStakingDualRewardsFactoryScript --fork-url "https://polygon-mumbai.g.alchemy.com/v2/0zYR0X60apvZglZAMDnA7dHmE7lG4amL" --broadcast --verify -vvvv  


#  forge verify-contract --chain-id 5 --num-of-optimizations 1000000 --watch --constructor-args $(cast abi-encode "constructor(address,address,address,address)"  ) --compiler-version v0.7.6+commit.7338295f 0xD790FA41D1116253fd468832e2B47C02F82E9Ef9 src/StakingDualRewards.sol:StakingDualRewards GSWUYPSZGBKJ168A2M78TF7VUA97AP6G22



# 0x904fC8206D05d97b77171b63De8B23eeC61b1fB3 0x1837d2285980853b0fe02AaD766a9403e311a4f4 0xd056Deaa25C6D5C7A93D5EAC37Bb78b5265D2e15 0x0737593086022272629670bBd207918ea9189484