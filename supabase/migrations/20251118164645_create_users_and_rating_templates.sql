-- Create users table
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  username text not null unique,
  bio text,
  location text,
  favorite_drink text,
  instagram_handle text,
  avatar_url text,
  banner_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Ensure trigger exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_users_updated_at'
  ) THEN
    CREATE TRIGGER set_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
END $$;

-- Create rating_templates
create table if not exists public.rating_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  template_json jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_rating_templates_updated_at'
  ) THEN
    CREATE TRIGGER set_rating_templates_updated_at
    BEFORE UPDATE ON public.rating_templates
    FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
END $$;

-- Enable RLS
alter table public.users enable row level security;
alter table public.rating_templates enable row level security;

-- Users policies
create policy users_self_select
  on public.users
  for select using (auth.uid() = id);

create policy users_self_insert
  on public.users
  for insert with check (auth.uid() = id);

create policy users_self_update
  on public.users
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Rating templates policies
create policy rating_self_select
  on public.rating_templates
  for select using (auth.uid() = user_id);

create policy rating_self_insert
  on public.rating_templates
  for insert with check (auth.uid() = user_id);

create policy rating_self_update
  on public.rating_templates
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
;
