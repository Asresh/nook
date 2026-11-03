create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  topic text not null default '' check (char_length(topic) <= 80),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.rooms enable row level security;

drop policy if exists "rooms are readable by authenticated users" on public.rooms;
create policy "rooms are readable by authenticated users"
  on public.rooms
  for select
  to authenticated
  using (true);

drop policy if exists "authenticated users can create rooms" on public.rooms;
create policy "authenticated users can create rooms"
  on public.rooms
  for insert
  to authenticated
  with check (auth.uid() = created_by);

create index if not exists rooms_created_at_idx
  on public.rooms (created_at desc);
