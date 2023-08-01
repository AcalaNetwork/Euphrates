import dotenv from 'dotenv';
import { HardhatUserConfig } from 'hardhat/config';
import "@typechain/hardhat";
import "@nomiclabs/hardhat-waffle";
import "hardhat-preprocessor";
import '@primitivefi/hardhat-dodoc';
import fs from "fs";

dotenv.config();

function getRemappings() {
    return fs
        .readFileSync("remappings.txt", "utf8")
        .split("\n")
        .filter(Boolean) // remove empty lines
        .map((line) => line.trim().split("="));
}

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.17",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    networks: {
        mandala: {
            url: 'http://127.0.0.1:8545',
            accounts: {
                mnemonic: 'fox sight canyon orphan hotel grow hedgehog build bless august weather swarm',
                path: 'm/44\'/60\'/0\'/0',
            },
            chainId: 595,
        },
        karuraTestnet: {
            url: 'https://eth-rpc-karura-testnet.aca-staging.network',
            accounts: {
                mnemonic: 'fox sight canyon orphan hotel grow hedgehog build bless august weather swarm',
                path: 'm/44\'/60\'/0\'/0',
            },
            chainId: 596,
        },
        karura: {
            url: 'https://eth-rpc-karura.aca-api.network',
            accounts: process.env.KEY ? [process.env.KEY] : [],
            chainId: 686,
        },
        acala: {
            url: 'https://eth-rpc-acala.aca-api.network',
            accounts: process.env.KEY ? [process.env.KEY] : [],
            chainId: 787,
        },
    },
    mocha: {
        timeout: 600000, // 10 min
    },
    preprocess: {
        eachLine: (hre) => ({
            transform: (line: string) => {
                if (line.match(/^\s*import /i)) {
                    for (const [from, to] of getRemappings()) {
                        if (line.includes(from)) {
                            line = line.replace(from, to);
                            break;
                        }
                    }
                }
                return line;
            },
        }),
    },
    paths: {
        sources: "./src",
        cache: "./cache_hardhat",
    },
    dodoc: {
        outputDir: './docs'
    }
};

export default config;