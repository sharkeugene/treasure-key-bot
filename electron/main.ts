import { app, BrowserWindow, ipcMain } from "electron";
import * as path from "path";
import * as url from "url";
import { load } from "./contracts";
import { getCurrentRoundInfo, getPlayerInfo } from "./bot";

type Await<T> = T extends PromiseLike<infer U> ? U : T;

let mainWindow: Electron.BrowserWindow | null;
let CONTRACTS: Await<ReturnType<typeof load>> = {} as any;
let AFK_MODE_INTERVAL: NodeJS.Timeout | null = null;
let SNIPE_START_INTERVAL: NodeJS.Timeout | null = null;

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
    if (SNIPE_START_INTERVAL === null) {
      SNIPE_START_INTERVAL = setInterval(async () => {
        const info = await getCurrentRoundInfo(CONTRACTS.better);
        const player = await getPlayerInfo(
          CONTRACTS.better,
          CONTRACTS.account.address
        );
        console.log(info);
        console.log(player);
      }, 3000);
    } else {
      clearInterval(SNIPE_START_INTERVAL);
      SNIPE_START_INTERVAL = null;
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

app.on("ready", createWindow);
app.allowRendererProcessReuse = true;
