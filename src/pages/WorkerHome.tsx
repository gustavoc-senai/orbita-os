import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { CalendarDays, ClipboardCheck, Clock3, ArrowRight, Wrench } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { Badge, Button, Empty, Loading, PageHeader, SectionCard, StatCard } from '../components/UI';
import { datetime } from '../lib/format';
export default function WorkerHome(){
 const {user,organization}=useAuth();const navigate=useNavigate();const org=organization?.id||'';
 const {data,isLoading,error,refetch}=useQuery({queryKey:['worker-home',org,user?.id],enabled:!!org&&!!user,queryFn:async()=>{
  const [jobs,appointments]=await Promise.all([
   supabase.from('work_orders').select('id,title,number,status,priority,scheduled_at,due_at,assigned_to').eq('organization_id',org).eq('assigned_to',user!.id).order('created_at',{ascending:false}).limit(100),
   supabase.from('calendar_events').select('id,title,starts_at,ends_at').eq('organization_id',org).eq('assigned_to',user!.id).gte('starts_at',new Date().toISOString()).order('starts_at').limit(20)
  ]);if(jobs.error)throw jobs.error;if(appointments.error)throw appointments.error;
  return {jobs:jobs.data||[],appointments:appointments.data||[]}
 }});
 if(isLoading)return <Loading/>;
 if(error)return <div className="module-error"><h2>Não foi possível carregar suas tarefas</h2><p>{error.message}</p><Button onClick={()=>void refetch()}>Tentar novamente</Button></div>;
 const jobs=data?.jobs||[],upcoming=data?.appointments||[],pending=jobs.filter(j=>!['DONE','CANCELED'].includes(j.status));
 return <><PageHeader eyebrow="ÁREA DO FUNCIONÁRIO" title={`Meu espaço de trabalho, ${(user?.user_metadata?.full_name||user?.email||'profissional').split(' ')[0]}`} description={`Equipe ${organization?.name||''} · Atendimentos atribuídos à sua conta.`} actions={<Button onClick={()=>navigate('/app/agenda')}><CalendarDays size={16}/> Minha agenda</Button>}/>
 <div className="stat-grid"><StatCard title="Minhas ordens" value={String(jobs.length)} icon={<ClipboardCheck size={19}/>} delta="Atribuídas a você"/><StatCard title="Pendentes" value={String(pending.length)} icon={<Clock3 size={19}/>} delta="Precisam de acompanhamento"/><StatCard title="Concluídas" value={String(jobs.filter(j=>j.status==='DONE').length)} icon={<Wrench size={19}/>} delta="Atendimentos finalizados"/><StatCard title="Compromissos futuros" value={String(upcoming.length)} icon={<CalendarDays size={19}/>} delta="Na sua agenda"/></div>
 <div className="detail-grid"><SectionCard title="Minhas ordens de serviço" description="Acesse os detalhes e acompanhe o atendimento">{jobs.length?jobs.map(j=><button className="worker-job" key={j.id} onClick={()=>navigate(`/app/detalhes/work_orders/${j.id}`)}><div><strong>#{j.number} · {j.title}</strong><p>{j.scheduled_at?datetime(j.scheduled_at):'Sem horário agendado'}</p></div><Badge value={j.status}/><ArrowRight size={16}/></button>):<Empty title="Nenhuma ordem atribuída" description="Quando a empresa atribuir uma ordem a você, ela aparecerá aqui."/>}</SectionCard><SectionCard title="Próximos compromissos" description="Eventos atribuídos ao seu usuário">{upcoming.length?upcoming.map(e=><div className="worker-appointment" key={e.id}><CalendarDays size={18}/><div><strong>{e.title}</strong><p>{datetime(e.starts_at)}</p></div></div>):<Empty title="Agenda livre" description="Você não tem compromissos futuros agendados."/>}</SectionCard></div></>
}
