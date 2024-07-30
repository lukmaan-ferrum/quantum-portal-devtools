import { ethers } from 'ethers';
import { connectGateway, mine, mineEthBlock } from './utils.js';
import hre from 'hardhat';
const { accounts } = require('../config/account.js');

async function getWallet(network)  {
    let wallet;
    if (network.includes("localhost")) {
        wallet = ethers.Wallet.fromMnemonic(accounts.mnemonic);
        // console.log('Test account used from MNEMONIC', wallet.privateKey, wallet.address);
    } else {
        let wallet;
        wallet = new ethers.Wallet("0x86315a4684c58910bf1bc496b9173ca2c2370450b1e1569ff171889ac3c7331b");
        return wallet;
    }
    return wallet;
  }


async function getProvider(network) {
    const provider = new ethers.providers.JsonRpcProvider((hre.config.networks[network] as any).url)
    const chainId = await provider.getNetwork().then((network) => network.chainId);
    
    return { provider, chainId };
}

async function mineQp(ngate1, ngate2) {
    if (!ngate1 || !ngate2) {
        throw new Error('Please provide two networks with gateways to mine. SourceNetwork:Gateway => TargetNetwork:Gateway');
    }
    const [network1, gateway1] = ngate1.split(':');
    const [network2, gateway2] = ngate2.split(':');
    console.log(network1, gateway1, network2, gateway2);
    const p1 = await getProvider(network1);
    const p2 = await getProvider(network2);
    const blockNumber1 = await p1.provider.getBlockNumber();
    const blockNumber2 = await p2.provider.getBlockNumber();
    console.log(`PROVIDERS: ${blockNumber1} and ${blockNumber2}`);
    console.log(`Connecting to ${gateway1} on ${network1}`);
    const w1 = (await getWallet(network1)).connect(p1.provider);
    const chain1 = await connectGateway(w1, gateway1);
    console.log(`Connecting to ${gateway2} on ${network2}`);
    const w2 = (await getWallet(network2)).connect(p2.provider);
    const chain2 = await connectGateway(w2, gateway2);
    console.log(`Mining from chain ${network1}:${gateway1} to ${network2}:${gateway2}`);

    // Push time forward on local chains
    if (network1.includes('localhost') || network2.includes('localhost')) {
        await mineEthBlock(w1.provider);
        await mineEthBlock(w2.provider);
    }

    await mine(chain1, chain2);
}

async function main() {
    const argv = process.argv.slice(2);
    const ngate1 = argv[0];
    const ngate2 = argv[1];
    await mineQp(ngate1, ngate2);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });