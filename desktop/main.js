// Electron wrapper: serves the game over a private app:// address (so fetch() of the JSON/atlas files works and
// localStorage keeps a stable address), and keeps saves in the app's own data folder on disk.
const { app, BrowserWindow, protocol, net, Menu, shell } = require('electron');
const path = require('path'), { pathToFileURL } = require('url');

const GAME = app.isPackaged ? path.join(process.resourcesPath, 'game') : path.join(__dirname, '..');
protocol.registerSchemesAsPrivileged([{ scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } }]);

function createWindow() {
  const win = new BrowserWindow({ width: 1600, height: 950, backgroundColor: '#000', title: 'Stellar Horizons', autoHideMenuBar: true, webPreferences: { contextIsolation: true } });
  win.loadURL('app://game/index.html');
  win.webContents.setWindowOpenHandler(({ url }) => { shell.openExternal(url); return { action: 'deny' }; });
}

app.whenReady().then(() => {
  protocol.handle('app', req => {
    const rel = decodeURIComponent(new URL(req.url).pathname).replace(/^\/+/, '') || 'index.html';
    const file = path.normalize(path.join(GAME, rel));
    if (!file.startsWith(path.normalize(GAME))) return new Response('Forbidden', { status: 403 });
    return net.fetch(pathToFileURL(file).toString());
  });
  Menu.setApplicationMenu(null);
  createWindow();
  app.on('activate', () => { if (!BrowserWindow.getAllWindows().length) createWindow(); });
});
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
