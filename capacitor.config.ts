import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.yacht.wallet',
  appName: 'Yacht Wallet',
  webDir: 'dist-mobile',
  bundledWebRuntime: false,
  ios: {
    // 'never' = WKWebView fills the screen truly edge-to-edge (under the
    // camera notch and home indicator). The app's own --safe-top/--safe-bottom
    // padding on TopBar / BottomNav / Dashboard then keeps UI inside the safe
    // zone while the navy/water backgrounds bleed to the physical edges.
    // 'always' (the old value) let iOS inset the whole webview inside the
    // safe area, so backgrounds stopped short of the notch and the manual
    // safe-area padding double-applied.
    contentInset: 'never',
  },
  android: {
    allowMixedContent: false,
  },
  server: {
    androidScheme: 'https',
  },
  plugins: {
    StatusBar: {
      // Paint the status bar transparent and let the web content (navy /
      // water-blue) show behind the clock + notch. 'DARK' style = light
      // (white) glyphs, legible on the dark navy chrome.
      overlaysWebView: true,
      style: 'DARK',
    },
  },
};

export default config;
