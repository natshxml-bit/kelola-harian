-- Jalankan di Supabase Dashboard > SQL Editor
-- Project: gyvtqjhpbjbqizevavjw

-- Enable UUID
create extension if not exists "uuid-ossp";

-- Categories
create table if not exists categories (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade,
  nama text not null,
  icon text default 'category',
  color bigint default 4280391411,
  tipe text check (tipe in ('pemasukan','pengeluaran')) not null,
  is_custom boolean default true,
  created_at timestamp default now()
);
alter table categories enable row level security;
create policy "user can manage own categories" on categories for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Transactions
create table if not exists transactions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade,
  category_id uuid references categories(id),
  category_name text,
  tipe text check (tipe in ('pemasukan','pengeluaran')) not null,
  nominal bigint not null,
  tanggal timestamp not null,
  catatan text,
  created_at timestamp default now()
);
alter table transactions enable row level security;
create policy "user can manage own transactions" on transactions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Savings Goals
create table if not exists savings_goals (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade,
  nama text not null,
  target bigint not null,
  terkumpul bigint default 0,
  auto_percent int default 0,
  deadline timestamp,
  created_at timestamp default now()
);
alter table savings_goals enable row level security;
create policy "user can manage own savings" on savings_goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Emergency Fund
create table if not exists emergency_fund (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade unique,
  target bigint default 3000000,
  terkumpul bigint default 0,
  auto_percent int default 5,
  created_at timestamp default now()
);
alter table emergency_fund enable row level security;
create policy "user can manage own emergency" on emergency_fund for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Realtime
alter publication supabase_realtime add table categories, transactions, savings_goals, emergency_fund;
