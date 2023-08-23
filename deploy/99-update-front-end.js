const {
    frontEndContractsFile,
    frontEndContractFile2,
    frontEndAbiLocation,
    frontEndAbiLocation2,
} = require("../helper-hardhat-config")
require("dotenv").config()
const fs = require("fs")
const { network, ethers } = require("hardhat")
const { parse } = require("path")

module.exports = async () => {
    if (process.env.UPDATE_FRONT_END) {
        console.log("writing to front end...")
        await updateContractAddresses()
        await updateAbi()
        console.log("Front end written")
    }
}
async function updateAbi() {
    const nftMarketplace = await ethers.getContractAt("NftMarketplace")
    fs.writeFileSync(
        `${frontEndAbiLocation}NftMarketplace.json`,
        nftMarketplace.interface.format(ethers.utils.FormatTypes.json)
    )
    fs.writeFileSync(
        `${frontEndAbiLocation2}NftMarketplace.json`,
        nftMarketplace.interface.format(ethers.utils.FormatTypes.json)
    )
    const basicNft = await ethers.getContractAt("BasicNft")
    fs.writeFileSync(
        `${frontEndAbiLocation}BasicNft.json`,
        basicNft.interface.format(ethers.utils.FormatTypes.json)
    )
    fs.writeFileSync(
        `${frontEndAbiLocation2}BasicNft.json`,
        basicNft.interface.format(ethers.utils.FormatTypes.json)
    )
}
async function updateContractAddresses() {
    const chainId = network.config.chainId.toString()
    const nftMarketplace = await ethers.getContractAt("NftMarketplace")
    const contractAddresses = JSON.parse(fs.readFileSync(frontEndContractsFile, "utf-8"))
    if (chainId in contractAddresses) {
        if (!contractAddresses[chainId]["NftMarketplace"].includes(nftMarketplace.address)) {
            contractAddresses[chainId]["nftMarketplace"].push(nftMarketplace.address)
        }
    } else {
        contractAddresses[chainId] = { NftMarketplace: [nftMarketplace.address] }
    }
    fs.writeFileSync(frontEndContractsFile, JSON.stringify(contractAddresses))
    fs.writeFileSync(frontEndContractFile2, JSON.stringify(contractAddresses))
}
module.exports.tags = ["all", "frontend"]
