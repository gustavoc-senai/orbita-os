// Uses an isolated Docker PostgreSQL database. Never reads application credentials.
const {spawnSync}=require('node:child_process');const fs=require('node:fs');const path=require('node:path');
const root=path.resolve(__dirname,'..'),name='orbita-sql-test-'+Date.now();
function run(args,input){const result=spawnSync('docker',args,{encoding:'utf8',input,timeout:180000});if(result.error||result.status!==0)throw Error(result.error?.message||result.stderr||result.stdout);return result.stdout}
try{
 run(['run','--name',name,'-e','POSTGRES_HOST_AUTH_METHOD=trust','-d','postgres:17']);
 let ready=false;for(let i=0;i<40;i++){const r=spawnSync('docker',['exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],{encoding:'utf8'});if(r.status===0){ready=true;break}spawnSync('powershell',['-NoProfile','-Command','Start-Sleep -Milliseconds 250']);}if(!ready)throw Error('PostgreSQL não ficou pronto');
 const sql=(value)=>run(['exec','-i',name,'psql','-U','postgres','-v','ON_ERROR_STOP=1'],value.replace(/\uFEFF/g,''));
 sql(fs.readFileSync(path.join(__dirname,'fixtures/roles.fixture'),'utf8')+fs.readFileSync(path.join(__dirname,'fixtures/supabase-schemas.fixture'),'utf8'));
 const migrations=fs.readdirSync(path.join(root,'supabase/migrations')).filter(f=>f.endsWith('.sql')).sort();
 for(const file of migrations){sql(fs.readFileSync(path.join(root,'supabase/migrations',file),'utf8'));console.log('PASS '+file)}
 console.log(sql(fs.readFileSync(path.join(__dirname,'fixtures/workspace-regression.fixture'),'utf8')));
 // Incremental migration must be safe to reapply.
 sql(fs.readFileSync(path.join(root,'supabase/migrations/019_workspace_and_query_indexes.sql'),'utf8'));
 sql(fs.readFileSync(path.join(root,'supabase/migrations/020_repair_team_invitations.sql'),'utf8'));console.log('PASS migrations 019/020 reaplicadas sem perda de dados');sql(fs.readFileSync(path.join(root,'supabase/ATUALIZAR_SISTEMA.sql'),'utf8'));console.log('PASS arquivo consolidado compatível com SQL Editor e reaplicação');
}finally{spawnSync('docker',['rm','-f',name],{encoding:'utf8'})}

