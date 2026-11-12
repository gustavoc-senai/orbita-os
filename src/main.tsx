import React from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter } from 'react-router-dom';
import { Toaster } from 'sonner';
import { AuthProvider } from './contexts/AuthContext';
import App from './App';
import './styles/global.css';
import './styles/enterprise.css';
import {useTheme} from './lib/workspace';
function ThemeToaster(){const {theme}=useTheme();React.useEffect(()=>{document.documentElement.dataset.theme=theme},[theme]);return <Toaster theme={theme as 'dark'|'light'} richColors position="top-right"/>}
const queryClient=new QueryClient({defaultOptions:{queries:{staleTime:20_000,refetchOnWindowFocus:false,retry:1}}});
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><QueryClientProvider client={queryClient}><BrowserRouter><AuthProvider><App/><ThemeToaster/></AuthProvider></BrowserRouter></QueryClientProvider></React.StrictMode>);
