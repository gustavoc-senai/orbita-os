import {useEffect,useMemo,useState} from 'react';
import {NavLink,Outlet,useLocation,useNavigate} from 'react-router-dom';
import {Activity,ArrowUpRight,Bell,Building2,ChevronDown,ChevronRight,Command,Gauge,Grid2X2,LayoutDashboard,LogOut,Menu,MessageCircle,Sparkles,Moon,PanelLeftClose,Plus,Search,Settings2,ShieldCheck,Star,Sun,Users,X,type LucideIcon} from 'lucide-react';
import {useQuery} from '@tanstack/react-query';
import {useAuth,canFinance,canManage} from '../contexts/AuthContext';
import {initials} from '../lib/format';
import {modules} from '../lib/modules';
import {canOpenModule,moduleCategory,useFavorites,useTheme} from '../lib/workspace';
import {supabase} from '../lib/supabase';
import {Modal} from './UI';
type NavItem=[string,string,LucideIcon];
export default function Layout(){
 const {user,organization,role,memberships,setCurrentOrganization,signOut}=useAuth();
 const location=useLocation(),navigate=useNavigate();
 const [mobile,setMobile]=useState(false),[collapsed,setCollapsed]=useState(false),[orgOpen,setOrgOpen]=useState(false),[search,setSearch]=useState(''),[searchOpen,setSearchOpen]=useState(false);
 const {theme,setTheme}=useTheme(),{favorites}=useFavorites();
 useEffect(()=>{setMobile(false);setSearchOpen(false);setOrgOpen(false)},[location.pathname]);
 useEffect(()=>{document.documentElement.dataset.theme=theme},[theme]);
 useEffect(()=>{const handler=(e:KeyboardEvent)=>{if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){e.preventDefault();setSearchOpen(v=>!v)}if(e.key==='Escape'){setMobile(false);setOrgOpen(false)}};document.addEventListener('keydown',handler);return()=>document.removeEventListener('keydown',handler)},[]);
 const {data:notifications=[]}=useQuery({queryKey:['notifications',organization?.id,user?.id],queryFn:async()=>{const {data,error}=await supabase.from('notifications').select('id').eq('organization_id',organization!.id).eq('user_id',user!.id).is('read_at',null).limit(100);if(error)throw error;return data||[]},enabled:!!organization&&!!user});
 const available=useMemo(()=>modules.filter(m=>canOpenModule(m,role)),[role]);
 const results=available.filter(m=>(m.title+' '+m.description+' '+moduleCategory(m.path)).toLocaleLowerCase('pt-BR').includes(search.toLocaleLowerCase('pt-BR')));
 const core:NavItem[]=[['/app','Visão geral',LayoutDashboard],['/app/modulos','Central de módulos',Grid2X2],['/app/ordens','Ordens de serviço',Gauge],['/app/agenda','Agenda',modules.find(m=>m.path==='agenda')!.icon],['/app/conversas','Conversas',MessageCircle],['/app/assistente','Órbita AI',Sparkles]];
 const centers:NavItem[]=[['/app/central-operacional','Operações',Gauge],...(canManage(role)?[['/app/central-comercial','Comercial e CRM',modules.find(m=>m.path==='leads')!.icon],['/app/gestao-pessoas','Gestão de pessoas',Users]] as NavItem[]:[]),...(canFinance(role)?[['/app/central-financeira','Financeiro',modules.find(m=>m.path==='faturas')!.icon]] as NavItem[]:[])];
 const admin:NavItem[]=[...(canManage(role)?[['/app/equipe','Equipe e convites',Users],['/app/relatorios','Relatórios',Gauge]] as NavItem[]:[]),...(['OWNER','ADMIN'].includes(role||'')?[['/app/auditoria','Auditoria',ShieldCheck]] as NavItem[]:[]),['/app/configuracoes','Configurações',Settings2]];
 const match=modules.find(m=>location.pathname==='/app/'+m.path);
 const pageTitle=[...core,...centers,...admin].find(([p])=>p===location.pathname)?.[1]||match?.title||(location.pathname.includes('/detalhes/')?'Detalhes do registro':location.pathname.endsWith('notificacoes')?'Notificações':'Workspace');
 const renderLinks=(items:NavItem[])=>items.map(([path,label,Icon])=><NavLink key={path} to={path} end={path==='/app'} title={label} onClick={()=>setMobile(false)} className={({isActive})=>`nav-link ${isActive?'active':''}`}><Icon size={18}/><span>{label}</span>{path==='/app/modulos'&&<small>{available.length}</small>}</NavLink>);
 const name=user?.user_metadata?.full_name||user?.email?.split('@')[0]||'Usuário';
 return <div className={`shell enterprise-shell ${collapsed?'collapsed':''}`}>
  <a className="skip-link" href="#workspace-content">Pular para o conteúdo</a>
  {mobile&&<button className="sidebar-overlay" aria-label="Fechar navegação" onClick={()=>setMobile(false)}/>}
  <aside className={`sidebar ${mobile?'sidebar-open':''}`} aria-label="Navegação principal">
   <div className="brand-row"><div className="brand-mark"><Activity size={24}/></div><div className="brand-title"><b>órbita<span>os</span></b><small>BUSINESS WORKSPACE</small></div><button className="sidebar-close" aria-label="Fechar menu" onClick={()=>setMobile(false)}><X size={20}/></button></div>
   <div className="workspace-switcher"><button className="workspace-picker" title={organization?.name} aria-expanded={orgOpen} onClick={()=>setOrgOpen(!orgOpen)}><div className="workspace-avatar">{initials(organization?.name||'Órbita')}</div><div className="workspace-text"><strong>{organization?.name||'Minha empresa'}</strong><span>Seu espaço de trabalho</span></div><ChevronDown size={15}/></button>
    {orgOpen&&<div className="workspace-options">{memberships.map(m=><button key={m.organization_id} onClick={()=>{setCurrentOrganization(m.organization_id);setOrgOpen(false)}}><Building2 size={15}/>{m.organizations.name}{m.organization_id===organization?.id&&<span>✓</span>}</button>)}<button onClick={()=>navigate('/setup')}><Plus size={15}/>Criar empresa</button></div>}
   </div>
   <nav className="sidebar-nav"><div className="nav-section-label">WORKSPACE</div>{renderLinks(core)}{role!=='TECHNICIAN'&&<><div className="nav-section-label">CENTRAIS DE GESTÃO</div>{renderLinks(centers)}</>}
    {favorites.some(p=>available.some(m=>m.path===p))&&<><div className="nav-section-label"><Star size={11}/> FAVORITOS</div>{renderLinks(available.filter(m=>favorites.includes(m.path)).slice(0,5).map(m=>['/app/'+m.path,m.title,m.icon]))}</>}
    <div className="nav-section-label">ADMINISTRAÇÃO</div>{renderLinks(admin)}
   </nav>
   <div className="sidebar-bottom"><NavLink to="/app/modulos" className="workspace-explore"><Grid2X2 size={20}/><div><strong>Seu negócio, conectado</strong><span>Explore todos os módulos</span></div><ArrowUpRight size={17}/></NavLink><button className="collapse-btn" onClick={()=>setCollapsed(!collapsed)} title={collapsed?'Expandir menu':'Recolher menu'} aria-label={collapsed?'Expandir menu':'Recolher menu'}><PanelLeftClose size={16}/><span>Recolher menu</span></button><div className="sidebar-profile"><div className="user-avatar">{initials(name)}</div><div className="sidebar-profile-info"><strong>{name}</strong><span>{({OWNER:'Proprietário',ADMIN:'Administrador',MANAGER:'Gestor',FINANCE:'Financeiro',DISPATCHER:'Atendimento',TECHNICIAN:'Técnico'} as Record<string,string>)[role||'']||'Membro'}</span></div><button title="Sair da conta" aria-label="Sair da conta" onClick={async()=>{await signOut();navigate('/login')}}><LogOut size={17}/></button></div></div>
  </aside>
  <div className="main-container"><header className="topbar"><div className="topbar-left"><button className="topbar-icon hamburger" aria-label="Abrir navegação" onClick={()=>setMobile(true)}><Menu size={20}/></button><span className="topbar-breadcrumb">{match?moduleCategory(match.path):'Workspace'}</span><ChevronRight size={14} className="crumb-arrow"/><strong className="topbar-page-title">{pageTitle}</strong></div><div className="topbar-right"><button className="enterprise-search-trigger" onClick={()=>setSearchOpen(true)} aria-label="Pesquisar módulos"><Search size={16}/><span>Buscar no workspace</span><kbd>Ctrl K</kbd></button><button className="topbar-icon" onClick={()=>setTheme(theme==='dark'?'light':'dark')} aria-label={theme==='dark'?'Ativar tema claro':'Ativar tema escuro'}>{theme==='dark'?<Sun size={18}/>:<Moon size={18}/>}</button><NavLink to="/app/notificacoes" className="topbar-icon notification-bell" aria-label={`Notificações: ${notifications.length} não lidas`}><Bell size={18}/>{notifications.length>0&&<i/>}</NavLink><div className="topbar-divider"/><button className="topbar-account" title="Meu perfil e empresa" onClick={()=>navigate('/app/configuracoes')}><div className="user-avatar">{initials(name)}</div><ChevronDown size={14}/></button></div></header>
   <main id="workspace-content" className="page-content" tabIndex={-1}><Outlet key={organization?.id}/></main><footer className="footer"><span>ÓRBITA OS <span className="footer-version">/ Enterprise Workspace</span></span><span><ShieldCheck size={13}/> {organization?.name}</span></footer></div>
  <Modal open={searchOpen} onClose={()=>setSearchOpen(false)} title="Encontre seu próximo passo" wide><div className="command-content"><label className="command-input"><Search size={20}/><input autoFocus placeholder="Clientes, projetos, financeiro..." value={search} onChange={e=>setSearch(e.target.value)}/><kbd>ESC</kbd></label><div className="command-results">{results.map(m=>{const Icon=m.icon;return <button key={m.path} onClick={()=>{navigate('/app/'+m.path);setSearchOpen(false)}}><span className="hub-icon"><Icon size={20}/></span><span><strong>{m.title}</strong><small>{moduleCategory(m.path)}</small></span><ArrowUpRight size={17}/></button>})}{!results.length&&<div className="empty"><h3>Nenhum módulo encontrado</h3><p>Experimente buscar por outra área da empresa.</p></div>}</div><div className="command-hint"><Command size={13}/> Ctrl + K para pesquisar em qualquer página</div></div></Modal>
 </div>
}
