import { app, BrowserWindow, ipcMain } from "electron";
import * as path from "path";
import * as url from "url";
import { load } from "./contracts";
import { buyKeys, getCurrentRoundInfo, getPlayerInfo } from "./bot";

type Await<T> = T extends PromiseLike<infer U> ? U : T;

let mainWindow: Electron.BrowserWindow | null;
let CONTRACTS: Await<ReturnType<typeof load>> = {} as any;
let AFK_MODE_INTERVAL: NodeJS.Timeout | null = null;
let SNIPE_START_INTERVAL: NodeJS.Timeout | null = null;

let LAST_ROUND = "0";
let IS_BUYING = false;

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
      mainWindow?.webContents?.send?.("loginSuccess", true);
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
    // Stores the current round ID, when bot is turned on
    const info = await getCurrentRoundInfo(CONTRACTS.better);
    LAST_ROUND = info.roundId;

    if (SNIPE_START_INTERVAL === null) {
      console.log("Starting snipe mode...");
      SNIPE_START_INTERVAL = setInterval(async () => {
        const info = await getCurrentRoundInfo(CONTRACTS.better);
        if (parseInt(info.roundId) > parseInt(LAST_ROUND) && !IS_BUYING) {
          IS_BUYING = true;
          LAST_ROUND = info.roundId;
          console.log("Sniping for keys now...");
          await buyKeys(CONTRACTS.better, CONTRACTS.account.address, "140");
          mainWindow?.webContents?.send?.(
            "logs",
            `[StartSniper] - Bought 140 keys at ${Date.now()}`
          );
          IS_BUYING = false;
        }
      }, 500);
    } else {
      console.log("Closing snipe mode...");
      clearInterval(SNIPE_START_INTERVAL);
      SNIPE_START_INTERVAL = null;
      mainWindow?.webContents?.send?.(
        "logs",
        `[StartSniper] - Shutting bot down`
      );
    }
  });

  // TODO: need test logic works
  ipcMain.on("enableAFKMode", async (_, arg) => {
    if (AFK_MODE_INTERVAL === null) {
      console.log("Starting AFK mode...");
      AFK_MODE_INTERVAL = setInterval(async () => {
        const info = await getCurrentRoundInfo(CONTRACTS.better);
        const player = await getPlayerInfo(
          CONTRACTS.better,
          CONTRACTS.account.address
        );
        LAST_ROUND = info.roundId;
        const now = Date.now() / 1000;
        const secondsToEnd = parseInt(info.roundEnds) - now;
        const isLeading = player.playerId === info.pirateKingId;

        console.log(secondsToEnd);
        console.log(info);
        console.log(player);

        if (secondsToEnd < 15 && !IS_BUYING && !isLeading) {
          IS_BUYING = true;
          console.log("Buying key now...");
          await buyKeys(CONTRACTS.better, CONTRACTS.account.address, "1");
          mainWindow?.webContents?.send?.(
            "logs",
            `[AFKMode] - Bought a key at ${Date.now()}`
          );
          IS_BUYING = false;
        }
      }, 1500);
    } else {
      console.log("Closing AFK mode...");
      clearInterval(AFK_MODE_INTERVAL);
      AFK_MODE_INTERVAL = null;
      mainWindow?.webContents?.send?.(
        "logs",
        `[AFKMode] - Shutting bot down`
      );
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

app.on("ready", createWindow);
app.allowRendererProcessReuse = true;
