// Wires the in-process RPC bridge for the mobile build. On extension builds
// this module is never imported; main.tsx only awaits it when YACHT_PLATFORM
// is 'mobile' so Rollup can tree-shake it out of the .crx bundle.
//
// The shim's chrome.runtime.sendMessage forwards to globalThis.__yachtMobileRpc.
// Here we point that handle at the background's exported handle() so the
// popup, lib/, and components keep using rpc() unchanged.

import { App } from '@capacitor/app';
import { StatusBar, Style } from '@capacitor/status-bar';
import { handle } from '../background/index';
import type { RpcEnvelope, RpcReply } from './messaging';

// Paint the status bar to match the wallet's navy background and let the
// WebView draw underneath it. Without overlay=true, env(safe-area-inset-top)
// reports 0 on Android and the layout double-pads the top of the screen.
void (async () => {
  try {
    await StatusBar.setOverlaysWebView({ overlay: true });
    await StatusBar.setBackgroundColor({ color: '#002849' });
    await StatusBar.setStyle({ style: Style.Dark });
  } catch { /* status bar plugin missing on web preview — ignore */ }
})();

const FAKE_SENDER = {
  id: chrome.runtime.id,
  url: chrome.runtime.getURL('index.html'),
} as unknown as chrome.runtime.MessageSender;

globalThis.__yachtMobileRpc = async (msg: unknown): Promise<RpcReply> => {
  const env = msg as RpcEnvelope | undefined;
  if (!env || env.rpc !== 'yacht') {
    return { ok: false, error: 'Invalid RPC envelope' };
  }
  try {
    const result = await handle(env.request, FAKE_SENDER);
    return { ok: true, result };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : String(e) };
  }
};

// Mobile auto-lock policy. The vault is NOT force-locked the instant the
// app is backgrounded — that made the wallet re-prompt for the password on
// every quick app-switch. Instead we note when the app left the foreground
// and, on resume, lock only if more wall-clock time has elapsed than the
// user's configured auto-lock interval (Settings → Auto-lock,
// `autoLockMinutes`; 0 disables auto-lock entirely). While the app stays
// foregrounded the existing chrome.alarms-based timer (armed by the
// background on unlock) still applies unchanged.
let backgroundedAt: number | null = null;

App.addListener('appStateChange', (state) => {
  if (!state.isActive) {
    backgroundedAt = Date.now();
    return;
  }
  // Resumed from background.
  void (async () => {
    try {
      if (backgroundedAt != null) {
        const awayMs = Date.now() - backgroundedAt;
        backgroundedAt = null;
        const settings = (await handle(
          { type: 'settings.get' },
          FAKE_SENDER,
        )) as { autoLockMinutes?: number };
        const mins = settings?.autoLockMinutes ?? 0;
        if (mins > 0 && awayMs >= mins * 60_000) {
          await handle({ type: 'vault.lock' }, FAKE_SENDER).catch(() => { /* best effort */ });
        }
      }
    } finally {
      // Always re-check status so App.tsx drops to the Unlock screen if the
      // vault got locked (here or by the foreground timer), and stays put
      // otherwise. Plain window event — App.tsx needs no Capacitor import
      // and it simply never fires on the desktop extension build.
      window.dispatchEvent(new Event('yacht:resumed'));
    }
  })();
});

export {};
