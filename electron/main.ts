import { app, BrowserWindow, ipcMain } from "electron";
import * as path from "path";
import * as url from "url";
import { load } from "./contracts";
import { buyKeys, buyWithETH, getCurrentRoundInfo, getPlayerInfo } from "./bot";
import Web3 from "web3";
import { LogDescription } from "ethers/lib/utils";

type Await<T> = T extends PromiseLike<infer U> ? U : T;

let mainWindow: Electron.BrowserWindow | null;
let CONTRACTS: Await<ReturnType<typeof load>> = {} as any;
let AFK_MODE_INTERVAL: NodeJS.Timeout | null = null;
let SNIPE_START_INTERVAL: NodeJS.Timeout | null = null;

let LAST_ROUND = "0";
let IS_BUYING = false;

// SNIPE mode variables
let SNIPE_ETH_TO_SPEND = "1";
let SNIPE_GAS_TO_SPEND = "10";
let SNIPE_SELECTED_CHEST = "0x3718B1a1Bae216055adb1330E142546A9b11Fb33";

// AFK mode variables
let AFK_KEYS_TO_BUY = "1.1"; // number of keys to buy
let AFK_SECONDS_TO_BUY = 15; // number of seconds before bot starts sending a buy order
let AFK_SELECTED_CHEST = "0x3718B1a1Bae216055adb1330E142546A9b11Fb33";

function log(msg: any) {
  console.log(msg);
  mainWindow?.webContents?.send?.("logs", msg);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    title: "Treasure Key Bet Bot",
    icon: url.format({
      pathname: path.join(__dirname, "Icon/Icon.icns"),
      protocol: "file:",
      slashes: true,
    }),
    // frame: false,
    webPreferences: {
      nodeIntegration: true,
      // webSecurity: false,
    },
  });
  mainWindow?.setTitle("Treasure Key Bet Bot");

  mainWindow?.on("page-title-updated", function (e) {
    e.preventDefault();
  });

  if (process.env.NODE_ENV === "development") {
    mainWindow.loadURL(`http://localhost:4000`);
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadURL(
      url.format({
        pathname: path.join(__dirname, "index.html"),
        protocol: "file:",
        slashes: true,
      })
    );
  }

  ipcMain.on("login", async (_, arg) => {
    const { password } = arg;
    try {
      CONTRACTS = await load(password);
      const player = await getPlayerInfo(
        CONTRACTS.better("0x3718B1a1Bae216055adb1330E142546A9b11Fb33"),
        CONTRACTS.account.address
      );
      console.log(player);

      mainWindow?.webContents?.send?.("loginSuccess", {
        address: CONTRACTS.account.address,
        playerName: player.playerName,
      });
    } catch (e) {
      mainWindow?.webContents?.send?.("loginFailed", true);
    }
  });

  /**
   * This function snipes the start of a new round
   */
  // TODO: enable the use of settings to tweak number of keys bought
  //TODO: enable the use of settings to tweak frequency of polling
  ipcMain.on("enableStartSnipe", async (_, arg) => {
    const { ethToSpend, gasToSpend = "10", selectedChest } = arg;
    log(`ethToSpend: ${ethToSpend}, gasToSpend: ${gasToSpend}`);
    SNIPE_ETH_TO_SPEND = `${ethToSpend}`;
    SNIPE_GAS_TO_SPEND = gasToSpend;
    SNIPE_SELECTED_CHEST = selectedChest;

    // Stores the current round ID, when bot is turned on
    const info = await getCurrentRoundInfo(CONTRACTS.better(SNIPE_SELECTED_CHEST));
    LAST_ROUND = info.roundId;

    if (SNIPE_START_INTERVAL === null) {
      log("Starting snipe mode...");
      SNIPE_START_INTERVAL = setInterval(async () => {
        const info = await getCurrentRoundInfo(CONTRACTS.better(SNIPE_SELECTED_CHEST));

        const potSize = parseFloat(Web3.utils.fromWei(info.currentPot)).toFixed(
          2
        );
        const now = Date.now() / 1000;
        const secondsToEnd = (parseInt(info.roundEnds) - now).toFixed(2);

        log(
          `last: ${LAST_ROUND}, current: ${info.roundId}, pot: ${potSize} BNB, seconds left: ${secondsToEnd}`
        );

        if (parseInt(info.roundId) > parseInt(LAST_ROUND) && !IS_BUYING) {
          IS_BUYING = true;
          LAST_ROUND = info.roundId;
          log("Sniping for keys now...");
          await buyWithETH(
            CONTRACTS.better(SNIPE_SELECTED_CHEST),
            CONTRACTS.account.address,
            Web3.utils.toWei(SNIPE_ETH_TO_SPEND, "ether"),
            SNIPE_GAS_TO_SPEND
          );
          log("after buyWithETH");
          IS_BUYING = false;
        }
      }, 800);
    } else {
      clearInterval(SNIPE_START_INTERVAL);
      SNIPE_START_INTERVAL = null;
      log(`[StartSniper] - Shutting bot down`);
    }
  });

  // TODO: need test logic works
  ipcMain.on("enableAFKMode", async (_, arg) => {
    const { keysToBuy = "1.1", secondsToBuy = 15, selectedChest } = arg;
    console.log({ keysToBuy, secondsToBuy });
    AFK_KEYS_TO_BUY = `${keysToBuy}`;
    AFK_SECONDS_TO_BUY = secondsToBuy;
    AFK_SELECTED_CHEST = selectedChest;

    if (AFK_MODE_INTERVAL === null) {
      log("Starting AFK mode...");
      AFK_MODE_INTERVAL = setInterval(async () => {
        const info = await getCurrentRoundInfo(CONTRACTS.better(AFK_SELECTED_CHEST));
        const player = await getPlayerInfo(
          CONTRACTS.better(AFK_SELECTED_CHEST),
          CONTRACTS.account.address
        );
        LAST_ROUND = info.roundId;
        const now = Date.now() / 1000;
        const secondsToEnd = parseInt(info.roundEnds) - now;
        const isLeading = player.playerId === info.pirateKingId;

        console.log(secondsToEnd);
        console.log(info);
        console.log(player);

        if (secondsToEnd < AFK_SECONDS_TO_BUY && !IS_BUYING && !isLeading) {
          IS_BUYING = true;
          log("Buying key(s) now...");
          await buyKeys(
            CONTRACTS.better(AFK_SELECTED_CHEST),
            CONTRACTS.account.address,
            AFK_KEYS_TO_BUY
          );
          log(`Bought ${AFK_KEYS_TO_BUY} key(s) at ${Date.now()}`);
          IS_BUYING = false;
        }
      }, 1500);
    } else {
      log("Closing AFK mode...");
      clearInterval(AFK_MODE_INTERVAL);
      AFK_MODE_INTERVAL = null;
      log(`[AFKMode] - Shutting bot down`);
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

app.on("ready", createWindow);
app.allowRendererProcessReuse = true;
