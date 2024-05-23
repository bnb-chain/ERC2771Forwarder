import {ethers} from 'hardhat';
import {sleep, toHuman} from "./helper";
import {execSync} from "child_process";
import fs from "fs";

const log = console.log
const contractName = 'TrustedForwarder';
const SAFE_SINGLETON_FACTORY_ADDRESS = '0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7'

const getContractBytecode = async (contractName: string) => {
    execSync("npx hardhat compile")
    await sleep(2)
    const hardhatBuildFilePath = __dirname + `/../artifacts/contracts/${contractName}.sol/${contractName}.json`
    const buildInfo = require(hardhatBuildFilePath)
    return buildInfo.bytecode
}

const clear0x = (hexStr: string) => {
    if (hexStr.startsWith('0x')) return hexStr.substring(2);
}

const main = async () => {
    const {chainId} = await ethers.provider.getNetwork();
    const signers = await ethers.getSigners();
    const operator = signers[0];

    const balance = await ethers.provider.getBalance(operator.address);
    log(`chainId = ${chainId}, operator.address: `, operator.address, toHuman(balance));

    const SALT = "0x0000000000000000000000000000000000000000000000000000000000001111"
    const contractByteCode = await getContractBytecode(contractName)
    const hash = ethers.solidityPackedKeccak256(
        ['bytes1', 'address', 'bytes32', 'bytes32'],
        ['0xff', SAFE_SINGLETON_FACTORY_ADDRESS, SALT, ethers.keccak256(contractByteCode)])

    const address = '0x' + hash.substring(26)
    const contractAddress = ethers.getAddress(address)
    log(`deployed ${contractName} address`, contractAddress)

    const tx = await operator.sendTransaction({
        to: SAFE_SINGLETON_FACTORY_ADDRESS,
        data: '0x' + clear0x(SALT) + clear0x(contractByteCode)
    })

    const receipt = await tx.wait(1)
    if (receipt) {
        log('deployed', receipt.hash)
    }

    let deployments = {
        ChainId: chainId.toString(),

        Operator: operator.address,
        TrustedForwarder: contractAddress,

        SingleTokenFactory: SAFE_SINGLETON_FACTORY_ADDRESS,
        DeploySalt: SALT,
        DeployBytecode: contractByteCode,

        DeployTxHash: receipt ? receipt.hash : '',
    };
    log(`deployments`, JSON.stringify(deployments, null, 2));

    const deploymentDir = __dirname + `/../deployment`;
    if (!fs.existsSync(deploymentDir)) {
        fs.mkdirSync(deploymentDir, { recursive: true });
    }
    fs.writeFileSync(`${deploymentDir}/${chainId}-deployment.json`, JSON.stringify(deployments, null, 2))
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
