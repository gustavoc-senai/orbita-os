import {useSyncExternalStore} from 'react';
import {canFinance,canManage} from '../contexts/AuthContext';
import type {Role} from './types';
import {modules,type ModuleDef} from './modules';

export const categories = [
 {title:'Administração',paths:['servicos']},
 {title:'Comercial',paths:['leads','opportunities','orcamentos','campaigns','referral-partners']},
 {title:'Clientes',paths:['clientes','locais','equipamentos','customer-segments']},
 {title:'Financeiro',paths:['faturas','despesas','cost-centers','financial-goals','contratos']},
 {title:'Compras',paths:['suppliers','purchase-orders','estoque']},
 {title:'Recursos Humanos',paths:['team-shifts','training-records']},
 {title:'Projetos',paths:['projects','project-milestones']},
 {title:'Qualidade',paths:['inspections','nonconformities']},
 {title:'Logística',paths:['vehicles','route-stops']},
 {title:'Atendimento',paths:['support-tickets','service-requests']},
 {title:'Processos',paths:['ordens','agenda','procedures','risk-register']},
 {title:'Relacionamento',paths:['customer-feedback','follow-ups','loyalty-rewards']},
];
export function canOpenModule(m:ModuleDef,role:Role|null){
 if(!role||role==='CLIENT')return false;
 if(role==='TECHNICIAN')return ['ordens','agenda','equipamentos'].includes(m.path);
 if(m.financial)return canFinance(role);
 return !m.managerOnly||canManage(role);
}
export const moduleCategory=(path:string)=>categories.find(c=>c.paths.includes(path))?.title||'Workspace';
const event='orbita-preferences';
const subscribe=(listener:()=>void)=>{window.addEventListener(event,listener);window.addEventListener('storage',listener);return()=>{window.removeEventListener(event,listener);window.removeEventListener('storage',listener)}};
const getFavorites=()=>localStorage.getItem('orbita-favorite-modules')||'[]';
export function useFavorites(){
 const raw=useSyncExternalStore(subscribe,getFavorites,()=> '[]');
 let favorites:string[]=[];
 try{const value:unknown=JSON.parse(raw);if(Array.isArray(value))favorites=value.filter((x):x is string=>typeof x==='string'&&modules.some(m=>m.path===x))}catch{/* Ignore invalid browser preferences. */}
 const toggle=(path:string)=>{const next=favorites.includes(path)?favorites.filter(x=>x!==path):[...favorites,path];localStorage.setItem('orbita-favorite-modules',JSON.stringify(next));window.dispatchEvent(new Event(event))};
 return {favorites,toggle};
}
export function useTheme(){
 const theme=useSyncExternalStore(subscribe,()=>localStorage.getItem('orbita-theme')==='light'?'light':'dark',()=> 'dark');
 const setTheme=(value:'light'|'dark')=>{localStorage.setItem('orbita-theme',value);document.documentElement.dataset.theme=value;window.dispatchEvent(new Event(event))};
 return {theme,setTheme};
}
