import {useEffect,useRef} from 'react';
export function useDialogFocus(open:boolean,onClose:()=>void){
 const ref=useRef<HTMLDivElement>(null),close=useRef(onClose);close.current=onClose;
 useEffect(()=>{
  if(!open)return;
  const previous=document.activeElement as HTMLElement|null;
  const overflow=document.body.style.overflow;document.body.style.overflow='hidden';
  const selector='button:not(:disabled),a[href],input:not(:disabled),select:not(:disabled),textarea:not(:disabled),[tabindex="0"]';
  const frame=requestAnimationFrame(()=>{(ref.current?.querySelector<HTMLElement>('[autofocus],input')||ref.current?.querySelector<HTMLElement>(selector)||ref.current)?.focus()});
  const handler=(e:KeyboardEvent)=>{if(e.key==='Escape'){e.preventDefault();close.current()}if(e.key==='Tab'){const elements=Array.from(ref.current?.querySelectorAll<HTMLElement>(selector)||[]).filter(el=>el.getClientRects().length);const first=elements[0],last=elements[elements.length-1];if(!first){e.preventDefault();return}if(e.shiftKey&&(document.activeElement===first||document.activeElement===ref.current)){e.preventDefault();last.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}}};
  document.addEventListener('keydown',handler);return()=>{cancelAnimationFrame(frame);document.removeEventListener('keydown',handler);document.body.style.overflow=overflow;previous?.focus()};
 },[open]);
 return ref;
}
