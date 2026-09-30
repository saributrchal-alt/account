-- Nathoeng Account: projects, vendors, bills and partial payments
create table if not exists account_projects (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  budget numeric(14,2) check (budget is null or budget >= 0),
  status text not null default 'active' check (status in ('active','completed','cancelled')),
  started_at date,
  completed_at date,
  created_at timestamptz not null default now()
);
create table if not exists account_vendors (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  contact_name text, phone text, tax_id text, address text, note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists account_expense_bills (
  id uuid primary key default gen_random_uuid(),
  bill_date date not null default current_date,
  project_id uuid references account_projects(id),
  vendor_id uuid references account_vendors(id),
  category_id uuid references account_categories(id),
  title text not null,
  bill_no text,
  amount numeric(14,2) not null check (amount > 0),
  description text,
  status text not null default 'unpaid' check (status in ('unpaid','partial','paid','void')),
  due_date date,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists account_expense_payments (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references account_expense_bills(id) on delete restrict,
  payment_date date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  fund_id uuid references account_funds(id),
  payment_method text not null default 'cash' check (payment_method in ('cash','bank_transfer','qr','cheque','other')),
  reference_no text, note text, created_by text,
  created_at timestamptz not null default now()
);
create index if not exists idx_expense_bills_project on account_expense_bills(project_id);
create index if not exists idx_expense_bills_vendor on account_expense_bills(vendor_id);
create index if not exists idx_expense_bills_status on account_expense_bills(status);
create index if not exists idx_expense_payments_bill on account_expense_payments(bill_id);
alter table account_projects enable row level security;
alter table account_vendors enable row level security;
alter table account_expense_bills enable row level security;
alter table account_expense_payments enable row level security;

create or replace function account_refresh_bill_status() returns trigger language plpgsql as $$
declare total_paid numeric; bill_total numeric; target uuid;
begin
 target := coalesce(new.bill_id, old.bill_id);
 select amount into bill_total from account_expense_bills where id=target;
 select coalesce(sum(amount),0) into total_paid from account_expense_payments where bill_id=target;
 if total_paid > bill_total then raise exception 'Payment exceeds outstanding bill amount'; end if;
 update account_expense_bills set status=case when total_paid=0 then 'unpaid' when total_paid<bill_total then 'partial' else 'paid' end, updated_at=now()
 where id=target and status<>'void';
 return coalesce(new,old);
end $$;
drop trigger if exists trg_account_refresh_bill_status on account_expense_payments;
create trigger trg_account_refresh_bill_status after insert or update or delete on account_expense_payments
for each row execute function account_refresh_bill_status();

create or replace view account_bill_balances as
select b.*, p.name project_name, v.name vendor_name,
 coalesce((select sum(x.amount) from account_expense_payments x where x.bill_id=b.id),0)::numeric(14,2) paid_amount,
 (b.amount-coalesce((select sum(x.amount) from account_expense_payments x where x.bill_id=b.id),0))::numeric(14,2) outstanding_amount
from account_expense_bills b
left join account_projects p on p.id=b.project_id
left join account_vendors v on v.id=b.vendor_id;