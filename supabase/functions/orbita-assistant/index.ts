import {handleAssistant} from './handler.ts';
Deno.serve((request:Request)=>handleAssistant(request,Deno.env));
