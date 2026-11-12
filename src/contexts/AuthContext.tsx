import {createContext,useCallback,useContext,useEffect,useRef,useState,type ReactNode} from 'react';
import {useQueryClient} from '@tanstack/react-query';
import type {Session,User} from '@supabase/supabase-js';
import {supabase} from '../lib/supabase';
import {errMessage} from '../lib/format';
import type {Org,Role} from '../lib/types';
type Membership={organization_id:string;role:Role;organizations:Org};
type AuthValue={user:User|null;session:Session|null;loading:boolean;authError:string|null;memberships:Membership[];organization:Org|null;role:Role|null;setCurrentOrganization:(id:string)=>void;refresh:()=>Promise<void>;signOut:()=>Promise<void>};
const Context=createContext<AuthValue|null>(null);
export function AuthProvider({children}:{children:ReactNode}){
 const queryClient=useQueryClient(),revision=useRef(0),identity=useRef<string|null>(null);
 const [session,setSession]=useState<Session|null>(null),[loading,setLoading]=useState(true),[authError,setAuthError]=useState<string|null>(null),[memberships,setMemberships]=useState<Membership[]>([]),[selected,setSelected]=useState<string|null>(null);
 const refresh=useCallback(async()=>{
  const request=++revision.current;setLoading(true);
  try{
   const {data:{session:active},error:sessionError}=await supabase.auth.getSession();if(sessionError)throw sessionError;if(request!==revision.current)return;
   if(identity.current!==active?.user.id){queryClient.clear();setMemberships([]);setSelected(null)}
   identity.current=active?.user.id||null;setSession(active);
   if(active){
    const {data,error}=await supabase.from('organization_members').select('organization_id,role,organizations(*)').eq('user_id',active.user.id).eq('status','ACTIVE');if(error)throw error;if(request!==revision.current)return;
    const links=(data||[]).map((item:any)=>({...item,organizations:Array.isArray(item.organizations)?item.organizations[0]:item.organizations})).filter((item:any)=>item.organizations) as Membership[];
    setMemberships(links);let saved:string|null=null;try{saved=localStorage.getItem(`orbita-workspace-${active.user.id}`)}catch{/* Browser storage may be unavailable. */}
    setSelected(current=>links.some(m=>m.organization_id===current)?current:links.some(m=>m.organization_id===saved)?saved:links[0]?.organization_id||null);
   }else{setMemberships([]);setSelected(null)}
   setAuthError(null);
  }catch(error){if(request===revision.current)setAuthError(errMessage(error))}finally{if(request===revision.current)setLoading(false)}
 },[queryClient]);
 useEffect(()=>{void refresh();const {data:{subscription}}=supabase.auth.onAuthStateChange(()=>{setTimeout(()=>void refresh(),0)});return()=>{revision.current++;subscription.unsubscribe()}},[refresh]);
 const organization=memberships.find(m=>m.organization_id===selected)?.organizations||memberships[0]?.organizations||null;
 const role=memberships.find(m=>m.organization_id===organization?.id)?.role||null;
 const setCurrentOrganization=(id:string)=>{setSelected(id);try{if(identity.current)localStorage.setItem(`orbita-workspace-${identity.current}`,id)}catch{/* The selection still works for this session. */}};
 const signOut=async()=>{const {error}=await supabase.auth.signOut();if(error)throw error;revision.current++;identity.current=null;queryClient.clear();setSession(null);setSelected(null);setMemberships([]);setAuthError(null);setLoading(false)};
 return <Context.Provider value={{user:session?.user||null,session,loading,authError,memberships,organization,role,setCurrentOrganization,refresh,signOut}}>{children}</Context.Provider>;
}
export function useAuth(){const value=useContext(Context);if(!value)throw Error('AuthProvider ausente');return value}
export const canManage=(role:Role|null)=>Boolean(role&&['OWNER','ADMIN','MANAGER'].includes(role));
export const canFinance=(role:Role|null)=>Boolean(role&&['OWNER','ADMIN','MANAGER','FINANCE'].includes(role));
