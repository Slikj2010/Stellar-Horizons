// Electron wrapper: serves the game over a private app:// address (so fetch() of the JSON/atlas files works and
// localStorage keeps a stable address; Electron stores it in the app's data folder), and checks GitHub Releases for updates.
const { app, BrowserWindow, protocol, net, Menu, shell, dialog } = require('electron');
const path = require('path'), { pathToFileURL } = require('url');

const GAME = app.isPackaged ? path.join(process.resourcesPath, 'game') : path.join(__dirname, '..');
const RELEASES = 'https://github.com/Slikj2010/Stellar-Horizons/releases/latest';
const PORTABLE = !!process.env.PORTABLE_EXECUTABLE_FILE; // portable .exe cannot replace itself, so it points to the download page
protocol.registerSchemesAsPrivileged([{ scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } }]);

let win = null, manual = false, updater = null;
function createWindow() {
  win = new BrowserWindow({ width: 1600, height: 950, backgroundColor: '#000', title: 'Stellar Horizons', autoHideMenuBar: true, webPreferences: { contextIsolation: true } });
  win.loadURL('app://game/index.html');
  win.webContents.setWindowOpenHandler(({ url }) => { shell.openExternal(url); return { action: 'deny' }; });
  win.on('closed', () => { win = null; });
}

function setupUpdater() {
  if (!app.isPackaged) return;
  try { updater = require('electron-updater').autoUpdater; } catch (e) { return; }
  updater.autoDownload = !PORTABLE; updater.autoInstallOnAppQuit = true;
  const box = o => dialog.showMessageBox(win || undefined, o);
  updater.on('update-available', info => {
    if (PORTABLE) box({ type: 'info', buttons: ['Open download page', 'Later'], defaultId: 0, message: `Version ${info.version} is available`, detail: 'This portable copy cannot update itself. Download the new version from the releases page.' }).then(r => { if (r.response === 0) shell.openExternal(RELEASES); });
    else if (manual) box({ type: 'info', message: `Version ${info.version} found`, detail: 'Downloading it now. You will be asked to restart when it is ready.' });
  });
  updater.on('update-not-available', () => { if (manual) box({ type: 'info', message: 'You have the latest version.', detail: `Stellar Horizons ${app.getVersion()}` }); manual = false; });
  updater.on('update-downloaded', info => box({ type: 'info', buttons: ['Restart now', 'Later'], defaultId: 0, message: `Version ${info.version} is ready`, detail: 'Restart to install it. Your saves are kept. It also installs when you next close the game.' }).then(r => { if (r.response === 0) updater.quitAndInstall(); }));
  updater.on('error', e => { if (manual) box({ type: 'warning', message: 'Could not check for updates', detail: String(e && e.message || e).slice(0, 300) }); manual = false; });
  updater.checkForUpdates().catch(() => {});
}
function checkNow() { if (!updater) { dialog.showMessageBox({ type: 'info', message: 'Updates are only checked in the installed app.' }); return; } manual = true; updater.checkForUpdates().catch(() => { manual = false; }); }

function buildMenu() {
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    { label: 'Game', submenu: [{ role: 'reload' }, { role: 'togglefullscreen' }, { type: 'separator' }, { role: 'quit' }] },
    { label: 'Help', submenu: [{ label: 'Check for updates', click: checkNow }, { label: 'Releases page', click: () => shell.openExternal(RELEASES) }, { type: 'separator' }, { label: `Version ${app.getVersion()}`, enabled: false }, { role: 'toggleDevTools' }] },
  ]));
}

app.whenReady().then(() => {
  protocol.handle('app', req => {
    const rel = decodeURIComponent(new URL(req.url).pathname).replace(/^\/+/, '') || 'index.html';
    const file = path.normalize(path.join(GAME, rel));
    if (!file.startsWith(path.normalize(GAME))) return new Response('Forbidden', { status: 403 });
    return net.fetch(pathToFileURL(file).toString());
  });
  buildMenu(); createWindow(); setupUpdater();
  app.on('activate', () => { if (!BrowserWindow.getAllWindows().length) createWindow(); });
});
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
