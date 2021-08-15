# defisaver-v3-contracts
All the contracts related to the Defi Saver ecosystem.

Detailed overview about that code can be found https://docs.defisaver.com

## To install
Run `npm install` or `yarn` in the repo folder.
You will also need to create a .env file as in the .env.example and fill it in with appropriate api keys.

## How to run tests

All of the tests are ran from the forked state of the mainnet. In the hardhat config you can change the 
block number the fork starts from. If it starts from an old state some tests might not work.

1. You first need to start a hardhat node from the forked mainnet with the following command:

`npx hardhat node --max-memory 8192  --fork ETHEREUM_NODE_URL`


2. After that you can run the tests, for example:

`npm run test local ./mcd/mcd-supply.js`

## How to deploy on a tenderly fork

1. In the .env file add the tenderly fork id where you want to deploy

2. In the `scripts/deploy-on-fork.js` add contracts you want to deploy using the `redeploy()` function and make sure to specify `reg.address` as second parameter. 

3. To deploy on fork run the following command: `npm run deploy fork deploy-on-fork`

## Common commands

`npm run compile` -  will compile all the contracts

`npm run deploy [network] [deploy-script]` - will deploy to the specified network by calling the script from the `/scripts` folder

`npm run test [network] [test-file]` - will run a test to the specified network by calling the script from the `/test` folder

`npm run verify [network] [contract-name]` - will verify contract based on address and arguments from `/deployments` folder

## Custom hardhat tasks

`npx hardhat customFlatten [contrac-name]` -  will flatten contract that is ready for deployment and put it in contracts/flattened folder

`npx hardhat customVerify [contract-address] [contract-name] --network [hardhat-settings-network-name]`  - will verify on etherscan if a contract was deployed using a single file from customFlatten task 

`npx hardhat fladepver [contract-name] [gas-in-gwei] [nonce (optional)] --network [hardhat-settings-network-name]` - will flatten to a single file (save it in contracts/flattened), deploy from it and then verify it on etherscan

`npx hardhat encryptPrivateKey [private-key] [secret-word]` - will encrypt the key with the secretWord. Put the output in .env as ENCRYPTED_KEY. Later on during deployment process it will ask you for secret word to decrypt the key for deployment use.