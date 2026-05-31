import { useState } from 'react';
import './App.css';

import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import { getToken } from './api/client';

export default function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(Boolean(getToken()));

  if (!isLoggedIn) {
    return <LoginPage onLogin={() => setIsLoggedIn(true)} />;
  }

  return <DashboardPage onLogout={() => setIsLoggedIn(false)} />;
}