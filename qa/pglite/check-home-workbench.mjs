import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { PGlite } from "@electric-sql/pglite";

const here = dirname(fileURLToPath(import.meta.url));
const repository = resolve(here, "../..");
const migration = await readFile(
  resolve(repository, "supabase/migrations/20260823140924_home_workbench_library.sql"),
  "utf8",
);
const visitColumnGrantsMigration = await readFile(
  resolve(
    repository,
    "supabase/migrations/20260824140932_home_workbench_visit_column_grants.sql",
  ),
  "utf8",
);
const ownerJournalBrewProjectionMigration = await readFile(
  resolve(
    repository,
    "supabase/migrations/20260824142054_owner_journal_brew_projection.sql",
  ),
  "utf8",
);
const contract = await readFile(
  resolve(repository, "supabase/tests/home_workbench_contract.sql"),
  "utf8",
);

const database = new PGlite();

await database.exec(`
  create role anon;
  create role authenticated;
  create schema auth;
  create schema private;
  create schema storage;

  create table auth.users (
    id uuid primary key,
    deleted_at timestamptz
  );

  create function auth.uid()
  returns uuid
  language sql
  stable
  as $$
    select nullif(
      coalesce(current_setting('request.jwt.claims', true), '{}')::jsonb ->> 'sub',
      ''
    )::uuid
  $$;

  create table storage.buckets (
    id text primary key,
    name text not null,
    public boolean not null default false,
    file_size_limit bigint,
    allowed_mime_types text[]
  );

  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text not null,
    name text not null,
    owner_id uuid,
    owner text
  );
  alter table storage.objects enable row level security;

  create function storage.foldername(path text)
  returns text[]
  language sql
  immutable
  as $$ select string_to_array(path, '/') $$;

  create table public.users (
    id uuid primary key,
    display_name text,
    username text,
    avatar_url text
  );

  create table public.visits (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    brew_method text,
    equipment text,
    brew_details jsonb not null default '{}'::jsonb,
    upload_state text not null default 'complete',
    created_at timestamptz not null default now()
  );

  create table public.recipe_identities (
    id uuid primary key,
    user_id uuid not null,
    name text not null
  );

  create table public.recipe_versions (
    id uuid primary key,
    recipe_identity_id uuid not null,
    version_number integer not null,
    version_label text,
    brew_details jsonb not null default '{}'::jsonb,
    brew_method text,
    equipment text,
    source_visit_id uuid,
    visibility text not null,
    source_kind text not null,
    redistribution_allowed boolean not null default false,
    source_recipe_version_id uuid,
    created_at timestamptz not null default now()
  );

  create table public.visit_tags (
    visit_id uuid not null,
    tagged_user_id uuid not null,
    tagged_by uuid not null,
    created_at timestamptz not null default now()
  );

  create function private.can_project_recipe_version_as(uuid, uuid)
  returns boolean
  language sql
  stable
  as $$ select true $$;

  create function private.build_owner_data_export_with_retired_shared_v2()
  returns jsonb
  language sql
  stable
  as $$
    select jsonb_build_object(
      'collaboration', '{}'::jsonb,
      'export_manifest', jsonb_build_object('included_collections', '[]'::jsonb),
      'social', '{}'::jsonb,
      'media_references', '[]'::jsonb
    )
  $$;

  create function private.guard_account_storage_write_v3()
  returns trigger
  language plpgsql
  as $$
  declare target_bucket text := coalesce(new.bucket_id, old.bucket_id);
  begin
    if target_bucket not in ('profile-media') then
      return coalesce(new, old);
    end if;
    return coalesce(new, old);
  end
  $$;

  create function public.prepare_account_deletion_v3(
    uuid, uuid, uuid, text, text, uuid, text
  )
  returns jsonb
  language plpgsql
  as $$
  declare target_bucket text := 'none';
  begin
    if target_bucket not in ('profile-media') then return '{}'::jsonb; end if;
    return '{}'::jsonb;
  end
  $$;

  create function public.seal_account_deletion_storage_preflight_v3(uuid, uuid)
  returns boolean
  language plpgsql
  as $$
  declare target_bucket text := 'none';
  begin
    if target_bucket not in ('profile-media') then return true; end if;
    return true;
  end
  $$;

  create function public.detach_account_storage_ownership_v3(uuid, uuid)
  returns void
  language plpgsql
  as $$
  declare target_bucket text := 'none';
  begin
    if target_bucket not in ('profile-media') then return; end if;
    return;
  end
  $$;
`);

await database.exec(migration);
await database.exec(visitColumnGrantsMigration);
await database.exec(ownerJournalBrewProjectionMigration);
const result = await database.exec(contract);
const contractResult = result
  .flatMap((statement) => statement.rows ?? [])
  .find((row) => row.result === "home_workbench_contract_passed");

if (!contractResult) {
  throw new Error("Home Workbench SQL contract did not report success");
}

await database.close();
console.log(
  "PGlite Home Workbench migration, RLS, Storage, deletion, projection, and export contracts passed",
);
