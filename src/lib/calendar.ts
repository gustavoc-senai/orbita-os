/** Calendar helpers use local dates so a day click preserves the user's wall clock. */
export const dayKey=(value:Date)=>`${value.getFullYear()}-${String(value.getMonth()+1).padStart(2,'0')}-${String(value.getDate()).padStart(2,'0')}`;
export const localInput=(value:Date)=>`${dayKey(value)}T${String(value.getHours()).padStart(2,'0')}:${String(value.getMinutes()).padStart(2,'0')}`;
export const startOfDay=(value:Date)=>new Date(value.getFullYear(),value.getMonth(),value.getDate());
export function addDays(value:Date,days:number){const next=new Date(value);next.setDate(next.getDate()+days);return next}
export function weekDays(value:Date){const start=addDays(startOfDay(value),-value.getDay());return Array.from({length:7},(_,i)=>addDays(start,i))}
export function monthDays(value:Date){const first=new Date(value.getFullYear(),value.getMonth(),1);const start=addDays(first,-first.getDay());return Array.from({length:42},(_,i)=>addDays(start,i))}
export type CalendarEvent={id:string;title:string;starts_at:string;ends_at:string;assigned_to:string|null;notes:string|null};
export const eventsOnDay=(events:CalendarEvent[],day:Date)=>events.filter(e=>new Date(e.starts_at)<addDays(startOfDay(day),1)&&new Date(e.ends_at)>startOfDay(day));
export function positionEvents(events:CalendarEvent[],day:Date){
 const start=startOfDay(day).getTime(),end=addDays(startOfDay(day),1).getTime();
 const sorted=eventsOnDay(events,day).map(event=>({event,start:Math.max(start,new Date(event.starts_at).getTime()),end:Math.min(end,new Date(event.ends_at).getTime())})).sort((a,b)=>a.start-b.start||a.end-b.end);
 const lanes:number[]=[];
 const positions=sorted.map(item=>{let lane=lanes.findIndex(finish=>finish<=item.start);if(lane<0)lane=lanes.length;lanes[lane]=item.end;const time=new Date(item.start),finish=new Date(item.end);const top=(time.getHours()*60+time.getMinutes())/60*56;const bottom=item.end===end?24*56:(finish.getHours()*60+finish.getMinutes())/60*56;return {...item,lane,top,height:Math.max(24,bottom-top)}});
 return positions.map(item=>({...item,lanes:Math.max(1,lanes.length)}));
}
