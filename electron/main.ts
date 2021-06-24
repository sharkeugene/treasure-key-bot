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

  ipcMain.on("login", (_, arg) => {
    const { password } = arg;
    load(password)
      .then((contracts) => {
        CONTRACTS = contracts;
        mainWindow?.webContents?.send?.("loginSuccess", true);
      })
      .catch(() => {
        mainWindow?.webContents?.send?.("loginFailed", true);
      });
  });

  ipcMain.on("enableStartSnipe", async (_, arg) => {
    console.log("Starting snipe")
    if (SNIPE_START_INTERVAL === null) {
      console.log("Starting snipe mode...")
      SNIPE_START_INTERVAL = setInterval(async () => {
        const info = await getCurrentRoundInfo(CONTRACTS.better);
        const player = await getPlayerInfo(
          CONTRACTS.better,
          CONTRACTS.account.address
        );
        console.log(info);
        console.log(player);
      }, 500);
    } else {
      clearInterval(SNIPE_START_INTERVAL);
      SNIPE_START_INTERVAL = null;
    }
  });

  // TODO: need test logic works
  ipcMain.on("enableAFKMode", async (_, arg) => {
    console.log("Starting AFK mode")
    if (AFK_MODE_INTERVAL === null) {
      console.log("Starting AFK mode...")
      AFK_MODE_INTERVAL = setInterval(async () => {
        const info = await getCurrentRoundInfo(CONTRACTS.better);
        const player = await getPlayerInfo(
          CONTRACTS.better,
          CONTRACTS.account.address
        );
        const now = Date.now() / 1000;
        const secondsToEnd = parseInt(info.roundEnds) - now;
        const isLeading = player.playerId !== info.pirateKingId;

        console.log(parseInt(info.roundEnds) - now)
        console.log(info);
        console.log(player);

        if (secondsToEnd < 20 && !IS_BUYING && !isLeading) {
          IS_BUYING = true;
          console.log("Buying key now...");
          await buyKeys(CONTRACTS.better, CONTRACTS.account.address, "0.1");
          IS_BUYING = false;
        }
        
      }, 500);
    } else {
      clearInterval(AFK_MODE_INTERVAL);
      AFK_MODE_INTERVAL = null;
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

app.on("ready", createWindow);
app.allowRendererProcessReuse = true;
