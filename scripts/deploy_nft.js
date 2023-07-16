async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Logo = await ethers.getContractFactory("Logo")
  
    // Start deployment, returning a promise that resolves to a contract object
    const deploy = await Logo.deploy()
    await deploy.deployed()
    console.log("Contract deployed to address:", deploy.address)
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error)
      process.exit(1)
    })
  