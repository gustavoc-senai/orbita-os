import {useState} from 'react';
import {AlertCircle,RefreshCw} from 'lucide-react';
import {useAuth} from '../contexts/AuthContext';
import {Button} from './UI';
export default function AuthFailure(){const {authError,refresh,signOut}=useAuth();const [busy,setBusy]=useState(false);return <div className="setup-page"><div className="setup-card" role="alert"><AlertCircle size={28}/><h1>Vamos reconectar seu workspace</h1><p>Não conseguimos verificar seu acesso à empresa. Seus cadastros continuam preservados.</p><details><summary>Detalhe da conexão</summary><p className="muted-message">{authError}</p></details><div className="page-actions" style={{marginTop:24}}><Button disabled={busy} onClick={async()=>{setBusy(true);await refresh();setBusy(false)}}><RefreshCw size={16}/>Tentar novamente</Button><Button variant="outline" onClick={()=>void signOut()}>Sair da conta</Button></div></div></div>}
