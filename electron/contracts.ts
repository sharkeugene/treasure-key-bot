// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

import Web3 from "web3";
import Team from "../artifacts/contracts/Team.sol/Team.json";
import Book from "../artifacts/contracts/PlayerBook.sol/PlayerBook.json";
import TreasureKeyBet from "../artifacts/contracts/TreasureKeyBet.sol/TreasureKeyBet.json";
import { Account } from "web3/eth/accounts";

const PLAYER_BOOK = "0x3aC0aB02d56eF81D30B435D39a4b327b47643d78";
const TEAM = "0x554c709FDAE81C08F414468C5FfA9a814fcBdc01";
const BETTER = "0x3718B1a1Bae216055adb1330E142546A9b11Fb33";

export async function load(key: string) {
  const provider = new Web3.providers.HttpProvider(
    "https://bsc-dataseed.binance.org/"
  );
  const web3 = new Web3(provider);

  const account = web3.eth.accounts.wallet.add(key) as unknown as Account;

  const book = new web3.eth.Contract(
    Book.abi as any,
    PLAYER_BOOK
  );
  const team = new web3.eth.Contract(
    Team.abi as any,
    TEAM
  );
  const better = new web3.eth.Contract(
    TreasureKeyBet.abi as any,
    BETTER
  );

  return {
    team,
    account,
    better,
    book,
  };
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

// deploy();
// .then(() => process.exit(0))
// .catch((error) => {
//   console.error(error);
//   process.exit(1);
// });
