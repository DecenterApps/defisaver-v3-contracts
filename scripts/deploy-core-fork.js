const hre = require("hardhat");
const { deployContract } = require("./utils/deployer");
const { start } = require('./utils/starter');

const { changeConstantInFiles } = require('./utils/utils');

const { redeploy } = require('../test/utils');

const MAINNET_VAULT = '0xCCf3d848e08b94478Ed8f46fFead3008faF581fD';

async function main() {

    const proxyAuth = await deployContract("ProxyAuth");

    const adminVault = await deployContract("AdminVault");
    const reg = await deployContract("DFSRegistry");

    await changeConstantInFiles(
        "./contracts",
        ["StrategyExecutor"],
        "PROXY_AUTH_ADDR",
        proxyAuth.address
    );

    await changeConstantInFiles(
        "./contracts",
        ["AdminAuth"],
        "ADMIN_VAULT_ADDR",
        adminVault.address
    );

    await changeConstantInFiles(
        "./contracts",
        ["ActionBase", "TaskExecutor"],
        "REGISTRY_ADDR",
        reg.address
    );

    await run("compile");

    await redeploy("StrategyExecutor", reg.address);
    await redeploy("SubscriptionProxy", reg.address);
    await redeploy("Subscriptions", reg.address);
    await redeploy("TaskExecutor", reg.address);

    // mcd actions
    await redeploy("McdSupply", reg.address);
    await redeploy("McdWithdraw", reg.address);
    await redeploy("McdGenerate", reg.address);
    await redeploy("McdPayback", reg.address);
    await redeploy("McdOpen", reg.address);

    // aave actions
    await redeploy("AaveSupply", reg.address);
    await redeploy("AaveWithdraw", reg.address);
    await redeploy("AaveBorrow", reg.address);
    await redeploy("AavePayback", reg.address);

    // comp actions
    await redeploy("CompSupply", reg.address);
    await redeploy("CompWithdraw", reg.address);
    await redeploy("CompBorrow", reg.address);
    await redeploy("CompPayback", reg.address);

    // util actions
    await redeploy("PullToken", reg.address);
    await redeploy("SendToken", reg.address);
    await redeploy("SumInputs", reg.address);
    await redeploy("UnwrapEth", reg.address);
    await redeploy("WrapEth", reg.address);

    // exchange actions
    await redeploy("DFSSell", reg.address);
    await redeploy("DFSBuy", reg.address);

    // flashloan actions
    await redeploy("FLDyDx", reg.address);
    await redeploy("FLAaveV2", reg.address);

    // uniswap
    await redeploy("UniSupply", reg.address);
    await redeploy("UniWithdraw", reg.address);

    // switch back admin auth addr
    await changeConstantInFiles(
        "./contracts",
        ["AdminAuth"],
        "ADMIN_VAULT_ADDR",
        MAINNET_VAULT
    );

    await run("compile");
}

start(main);
