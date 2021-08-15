const {
    flatten,
    verifyContract,
    deployContract,
    sleep,
    findPathByContractName,
    encryptPrivateKey,
} = require('./hardhat-tasks-functions');

// eslint-disable-next-line no-undef
task('fladepver', 'Deploys and verifies contract on etherscan')
    .addOptionalPositionalParam('contractName', 'The name of the contract to flatten, deploy and verify')
    .addOptionalPositionalParam('gas', 'The price (in gwei) per unit of gas')
    .addOptionalPositionalParam('nonce', 'The nonce to use in the transaction')
    .setAction(async (args) => {
        await flatten(await findPathByContractName(args.contractName));
        const contractAddress = await deployContract(args.contractName, args);
        await sleep(30000);
        await verifyContract(contractAddress, args.contractName);
    });

// eslint-disable-next-line no-undef
task('customVerify', 'Verifies a contract on etherscan')
    .addOptionalPositionalParam('contractAddress', 'Address where the contract is deployed')
    .addOptionalPositionalParam('contractName', 'Name of the contract to verify')
    .setAction(async (args) => {
        await verifyContract(args.contractAddress, args.contractName);
    });

// eslint-disable-next-line no-undef
task('customFlatten', 'Flattens for our DFS team')
    .addOptionalPositionalParam('contractName', 'The contract to flatten')
    .setAction(async (args) => {
        await flatten(await findPathByContractName(args.contractName));
    });

// eslint-disable-next-line no-undef
task('encryptPrivateKey', 'Encrypt private key')
    .addOptionalPositionalParam('privateKey', 'Private key for eth address')
    .addOptionalPositionalParam('secretKey', 'Keyword for encryption and decryption')
    .setAction(async (args) => {
        encryptPrivateKey(args.privateKey, args.secretKey);
    });
