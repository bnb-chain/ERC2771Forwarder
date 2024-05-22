import { ethers } from 'hardhat';
import fs from "fs";
import {toHuman} from "./helper";
const log = console.log

const contractName = 'TrustedForwarder';

const main = async () => {
    const { chainId } = await ethers.provider.getNetwork();
    const signers = await ethers.getSigners();
    const operator = signers[0];

    const balance = await ethers.provider.getBalance(operator.address);
    log('operator.address: ', operator.address, toHuman(balance));

    const DeployArgs: string[] = []
    const contract = await ethers.deployContract(contractName, DeployArgs, operator);
    const contractAddress = await contract.getAddress()
    log('await contract.getAddress()', contractAddress);

    const tx = contract.deploymentTransaction();
    let deployments = {
        ChainId: chainId.toString(),

        Operator: operator.address,
        ERC2771Forwarder: contractAddress,

        DeployArgs,
        DeployTxHash: tx ? tx.hash : '',
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
