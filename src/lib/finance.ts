export type FinancialRow={status?:string;amount?:number|string;paid_amount?:number|string};
export function financialTotals(invoices:FinancialRow[],expenses:FinancialRow[]){
 const active=invoices.filter(i=>i.status!=='CANCELED');
 const billed=active.reduce((s,i)=>s+Number(i.amount||0),0);
 const received=active.reduce((s,i)=>s+Number(i.paid_amount||0),0);
 const pending=active.reduce((s,i)=>s+Math.max(0,Number(i.amount||0)-Number(i.paid_amount||0)),0);
 const paidExpenses=expenses.filter(e=>e.status==='PAID').reduce((s,e)=>s+Number(e.amount||0),0);
 return {billed,received,pending,paidExpenses,result:received-paidExpenses};
}
