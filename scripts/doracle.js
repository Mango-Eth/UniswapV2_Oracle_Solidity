const hre = require("hardhat");

async function main() {
    const Lip = await hre.ethers.getContractFactory("OracleBetter");
    const lip = await Lip.deploy("0x8fd1c16770c93fe8845786aa6f2fa8fdd822396d");

    await lip.deployed()
    .then(() => console.log(lip.address))
}


console.log("hi")
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });