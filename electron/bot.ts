import { ethers } from "ethers";
import Web3 from "web3";

export const EMPTY_AFFLIATE =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
export const BOT_AFFILIATE =
  "0x677265796265617264000000000000000000000000000000000000000000000";

type Response = {
  0: string;
  1: string;
  2: string;
  3: string;
  4: string;
  5: string;
  6: string;
  7: string;
  8: string;
};

export type RoundInfo = {
  icoAmount: string;
  roundId: string;
  totalKeys: string;
  roundEnds: string;
  roundStarted: string;
  currentPot: string;
  pirateKingId: string;
  pirateKingAddress: string;
  pirateKingName: string;
  pirateKingBytes: string;
  antiwhale: boolean;
  antiwhaleBnbRemaining: number;
};

export async function getCurrentRoundInfo(better: any) {
  const roundInfo = (await better?.methods
    .getCurrentRoundInfo()
    .call()) as Response;
  let firstRound = roundInfo[1] == "0";
  let pastPot = '0';
  if (!firstRound) {
    const pastRoundInfo = (await better?.methods
      .getPastRoundInfo(parseInt(roundInfo[1]) - 1)
      .call()) as Response;
    pastPot = pastRoundInfo[5];
  }
  const accruedBnb =
    parseFloat(Web3.utils.fromWei(roundInfo[5])) -
    parseFloat(Web3.utils.fromWei(pastPot)) / 2;
  const antiwhale = accruedBnb <= 6;
  const antiwhaleBnbRemaining = (6 - accruedBnb) / 0.6;
  return {
    icoAmount: roundInfo[0],
    roundId: roundInfo[1],
    totalKeys: roundInfo[2],
    roundEnds: roundInfo[3],
    roundStarted: roundInfo[4],
    currentPot: roundInfo[5],
    pirateKingId: roundInfo[6],
    pirateKingAddress: roundInfo[7],
    pirateKingName: ethers.utils.parseBytes32String(roundInfo[8]),
    pirateKingBytes: roundInfo[8],
    antiwhale: antiwhale,
    antiwhaleBnbRemaining: antiwhaleBnbRemaining,
  };
}

export async function getPlayerInfo(better: any, account: string) {
  const roundInfo = (await better?.methods
    .getCurrentRoundInfo()
    .call()) as Response;
  // const bnbBalance = await web3.eth.getBalance(account ?? "");
  const playerInfo = await (better?.methods
    .getPlayerInfoByAddress(account)
    .call() as Response);
  return {
    playerId: playerInfo[0],
    playerName: ethers.utils.parseBytes32String(playerInfo[1]),
    playerNameBytes: playerInfo[1],
    keysOwned: playerInfo[2],
    winnings: playerInfo[3],
    generalVault: playerInfo[4],
    affiliateVault: playerInfo[5],
    roundBNB: playerInfo[6],
    // bnbBalance: Web3.utils.fromWei(bnbBalance),
  };
}

/**
 * Function to buy keys
 * @param better Game contract
 * @param account Account address
 * @param numKeys Number of keys to buy in Ethers e.g. if i wish to buy 1.1 keys, i will input "1.1"
 * @returns
 */
export async function buyKeys(better: any, account: string, numKeys: string) {
  const price = await better?.methods
    .iWantXKeys(Web3.utils.toWei(`${numKeys}`, "ether"))
    .call();
  const gas = await better?.methods
    .buyXname(BOT_AFFILIATE)
    .estimateGas({ from: account, value: price });
  console.log("Gas limit", `${parseInt(`${gas * 1.5}`)}`);
  await better?.methods.buyXname(BOT_AFFILIATE).send({
    from: account,
    value: price,
    gas: `${parseInt(`${gas * 1.6}`)}`,
    gasPrice: 7000000000,
  });
}

/**
 * Function to buy based on ETH amount, gas limit at 2.5mil
 * @param better Game contract
 * @param account Account address
 * @param ethInWei Amount of ETH to spend
 * @param gasPrice Amount of gas to spend
 * @returns
 */
export async function buyWithETH(
  better: any,
  account: string,
  ethInWei: string,
  gasPrice: string
) {
  const gas = await better?.methods
    .buyXname(BOT_AFFILIATE)
    .estimateGas({ from: account, value: ethInWei });
  console.log("Gas limit", `${parseInt(`${gas * 40}`)}`);
  await better?.methods.buyXname(BOT_AFFILIATE).send({
    from: account,
    value: ethInWei,
    gas: `2500000`,
    gasPrice: parseInt(`${parseInt(gasPrice) * 1000000000}`),
  });
}
