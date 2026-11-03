-- EscalaPro: estrutura inicial multiempresa.
-- Execute no SQL Editor do Supabase. Revise e teste antes de usar com dados reais.
create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  company_id uuid references public.companies(id) on delete set null,
  role text not null default 'employee' check (role in ('owner','company_admin','employee')),
  created_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete set null,
  shift_date date not null,
  status text not null check (status in ('work','off')),
  notes text,
  created_at timestamptz not null default now(),
  unique(employee_id, shift_date)
);

create or replace function public.my_company_id()
returns uuid language sql stable security definer
set search_path = public
as $$ select company_id from public.profiles where id = auth.uid() $$;

create or replace function public.my_role()
returns text language sql stable security definer
set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.shifts enable row level security;

drop policy if exists "company members read company" on public.companies;
create policy "company members read company" on public.companies
for select to authenticated using (id = public.my_company_id());

drop policy if exists "users read profiles in company" on public.profiles;
create policy "users read profiles in company" on public.profiles
for select to authenticated using (id = auth.uid() or company_id = public.my_company_id());

drop policy if exists "admins update company profiles" on public.profiles;
create policy "admins update company profiles" on public.profiles
for update to authenticated using (company_id = public.my_company_id() and public.my_role() in ('owner','company_admin'))
with check (company_id = public.my_company_id() and role in ('company_admin','employee'));

drop policy if exists "members read posts" on public.posts;
create policy "members read posts" on public.posts
for select to authenticated using (company_id = public.my_company_id());

drop policy if exists "admins manage posts" on public.posts;
create policy "admins manage posts" on public.posts
for all to authenticated using (company_id = public.my_company_id() and public.my_role() in ('owner','company_admin'))
with check (company_id = public.my_company_id() and public.my_role() in ('owner','company_admin'));

drop policy if exists "members read shifts" on public.shifts;
create policy "members read shifts" on public.shifts
for select to authenticated using (company_id = public.my_company_id());

drop policy if exists "admins manage shifts" on public.shifts;
create policy "admins manage shifts" on public.shifts
for all to authenticated using (company_id = public.my_company_id() and public.my_role() in ('owner','company_admin'))
with check (company_id = public.my_company_id() and public.my_role() in ('owner','company_admin'));

-- IMPORTANTE:
-- O cadastro de empresas e a atribuição do primeiro administrador devem ser feitos
-- por uma rotina confiável no servidor, nunca expondo a chave service_role no navegador.
-- Não publique dados reais até revisar as políticas RLS e testar contas de empresas diferentes.
