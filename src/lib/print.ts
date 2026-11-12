import { money,date } from './format';

type Quote = { number?:number;title?:string;total?:number;valid_until?:string;notes?:string;status?:string };
type Item = {description:string;quantity:number;unit_price:number};
const escapeHtml=(v:unknown)=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));

/** Opens a printer-friendly quote; the user can save it as PDF from the browser. */
export function printQuote(quote:Quote,items:Item[],company:string,customer?:string){
 const page=window.open('','_blank','width=900,height=720');
 if(!page)throw Error('Permita janelas pop-up para imprimir o orçamento');
 page.opener=null;
 const rows=items.map(i=>`<tr><td>${escapeHtml(i.description)}</td><td>${escapeHtml(i.quantity)}</td><td>${money(Number(i.unit_price))}</td><td>${money(Number(i.quantity)*Number(i.unit_price))}</td></tr>`).join('');
 const content=`<!doctype html><html lang="pt-BR"><head><meta charset="UTF-8"><title>Orçamento ${escapeHtml(quote.number??'')}</title><style>
 *{box-sizing:border-box}body{font-family:Arial,Helvetica,sans-serif;color:#182034;padding:42px;max-width:950px;margin:auto}header{display:flex;justify-content:space-between;border-bottom:4px solid #7458ee;padding-bottom:20px;margin-bottom:32px}h1{font-size:24px;margin:0}h2{font-size:19px}.brand{font-size:25px;color:#6445c3;font-weight:800}small,.muted{color:#667085}table{border-collapse:collapse;width:100%;margin:25px 0}th,td{text-align:left;padding:13px 9px;border-bottom:1px solid #dfe3eb}th{background:#f5f3ff}.total{text-align:right;font-size:23px;font-weight:800}.notes{white-space:pre-wrap}footer{margin-top:70px;border-top:1px solid #e5e7eb;padding-top:14px;color:#667085;font-size:12px}@media print{body{padding:15px}@page{size:A4;margin:16mm}}</style></head><body>
 <header><div><div class="brand">${escapeHtml(company)}</div><small>PROPOSTA COMERCIAL</small></div><div><b>Nº ${escapeHtml(quote.number??'—')}</b><p class="muted">Emitido em ${escapeHtml(new Date().toLocaleDateString('pt-BR'))}</p></div></header>
 <h1>${escapeHtml(quote.title)}</h1><p>Cliente: <b>${escapeHtml(customer||'Conforme cadastro')}</b></p><p>Validade: ${quote.valid_until?escapeHtml(date(quote.valid_until)):'Não informada'} &nbsp; | &nbsp; Situação: ${escapeHtml(quote.status)}</p>
 <table><thead><tr><th>Descrição</th><th>Quantidade</th><th>Preço unitário</th><th>Subtotal</th></tr></thead><tbody>${rows||'<tr><td colspan="4">Sem itens cadastrados</td></tr>'}</tbody></table>
 <div class="total">Total: ${money(Number(quote.total??0))}</div>${quote.notes?`<h2>Observações</h2><p class="notes">${escapeHtml(quote.notes)}</p>`:''}
 <footer>Documento gerado pelo Órbita OS. Este orçamento não é nota fiscal nem comprovante de pagamento.</footer>
 <script>window.addEventListener('load',()=>window.print());</script></body></html>`;
 page.document.open();page.document.write(content);page.document.close();
}
