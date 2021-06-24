import { ethers } from "ethers";
import Web3 from "web3";

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
  const pastRoundInfo = (await better?.methods
    .getPastRoundInfo(parseInt(roundInfo[1]) - 1)
    .call()) as Response;
  const accruedBnb =
    parseFloat(Web3.utils.fromWei(roundInfo[5])) -
    parseFloat(Web3.utils.fromWei(pastRoundInfo[5])) / 2;
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
