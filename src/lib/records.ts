import {supabase} from './supabase';
export type Row=Record<string,any>;
/** Read every server page in a stable order; errors never become empty business data. */
export async function fetchAllRows(table:string,org:string,select='*',sort='id'):Promise<Row[]>{
 const rows:Row[]=[];let from=0;
 for(;;){const {data,error}=await supabase.from(table).select(select).eq('organization_id',org).order(sort).range(from,from+499);if(error)throw error;if(!data?.length)break;rows.push(...data);from+=data.length}
 return rows;
}
export type ListOptions={org:string;table:string;search:string;status:string;sort:string;ascending:boolean;page:number;size?:number};
export async function fetchRecords(options:ListOptions):Promise<{rows:Row[];total:number;statuses:string[]}>{
 const {data,error}=await supabase.rpc('workspace_records',{p_org:options.org,p_table:options.table,p_search:options.search.trim(),p_status:options.status,p_sort:options.sort,p_asc:options.ascending,p_offset:options.page*(options.size||15),p_limit:options.size||15});if(error)throw error;
 if(!data||!Array.isArray(data.rows)||typeof data.total!=='number')throw Error('A listagem retornou uma resposta inválida. Confira a migration 023.');
 return {rows:data.rows,total:data.total,statuses:Array.isArray(data.statuses)?data.statuses:[]};
}
export async function fetchExport(options:ListOptions){const rows:Row[]=[];for(let page=0;;page++){const result=await fetchRecords({...options,page,size:500});rows.push(...result.rows);if(rows.length>=result.total||!result.rows.length)break}return rows}
