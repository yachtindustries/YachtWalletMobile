import { useEffect } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { useApp } from './store';
import Welcome from './screens/Welcome';
import CreateWallet from './screens/CreateWallet';
import ImportWallet from './screens/ImportWallet';
import Unlock from './screens/Unlock';
import Dashboard from './screens/Dashboard';
import Send from './screens/Send';
import SendNft from './screens/SendNft';
import Receive from './screens/Receive';
import Swap from './screens/Swap';
import SearchScreen from './screens/Search';
import TokenDetail from './screens/TokenDetail';
import History from './screens/History';
import Settings from './screens/Settings';
import Accounts from './screens/Accounts';
import ConnectedSites from './screens/ConnectedSites';
import RequestApproval from './screens/RequestApproval';
import Chat from './screens/Chat';
import Achievements from './screens/Achievements';
import Profile from './screens/Profile';
import CollectionView from './screens/CollectionView';
import { AchievementToast } from './components/AchievementToast';

export default function App() {
  const { initialized, unlocked, refreshStatus, refreshSettings } = useApp();
  const loc = useLocation();
  const isRequestRoute = loc.pathname.startsWith('/request/');

  useEffect(() => {
    void refreshStatus();
    void refreshSettings();
  }, [refreshStatus, refreshSettings]);

  // On mobile the vault auto-locks when the app is backgrounded. When the
  // user comes back, re-check vault status so a locked vault immediately
  // sends them to the Unlock screen instead of letting them tap into a
  // wallet screen that then fails with "wallet is locked". The event is
  // dispatched by lib/mobile-rpc.ts on app resume; it never fires on the
  // desktop extension build, so this is a no-op there.
  useEffect(() => {
    function onResumed() {
      void refreshStatus();
    }
    window.addEventListener('yacht:resumed', onResumed);
    return () => window.removeEventListener('yacht:resumed', onResumed);
  }, [refreshStatus]);

  if (isRequestRoute) {
    return (
      <Routes>
        <Route path="/request/:id" element={<RequestApproval />} />
      </Routes>
    );
  }

  if (!initialized) {
    return (
      <Routes>
        <Route path="/" element={<Welcome />} />
        <Route path="/create" element={<CreateWallet />} />
        <Route path="/import" element={<ImportWallet />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    );
  }

  if (!unlocked) {
    return (
      <Routes>
        <Route path="/" element={<Unlock />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    );
  }

  return (
    <>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/send" element={<Send />} />
        <Route path="/send-nft" element={<SendNft />} />
        <Route path="/receive" element={<Receive />} />
        <Route path="/swap" element={<Swap />} />
        <Route path="/search" element={<SearchScreen />} />
        <Route path="/token/:address" element={<TokenDetail />} />
        <Route path="/history" element={<History />} />
        <Route path="/chat" element={<Chat />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/settings/sites" element={<ConnectedSites />} />
        <Route path="/accounts" element={<Accounts />} />
        <Route path="/achievements" element={<Achievements />} />
        <Route path="/profile/:address" element={<Profile />} />
        <Route path="/collection/:contract" element={<CollectionView />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      {/* Mounted here so newly-unlocked achievements can pop over any
          screen the user happens to be on when sync resolves. */}
      <AchievementToast />
    </>
  );
}
