import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const repoPath = fileURLToPath(new URL('../../', import.meta.url))
const userID = '10000000-0000-4000-8000-000000000001'
const legacyVisitID = '20000000-0000-4000-8000-000000000001'

const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

await db.exec(String.raw`
create table public.users (
  id uuid primary key,
  created_at timestamptz not null default now()
);

create table public.visits (
  id uuid primary key,
  user_id uuid not null references public.users(id),
  drink_type text,
  drink_subtype text,
  caption text not null,
  visibility text not null,
  upload_state text not null,
  ratings jsonb not null default '{}'::jsonb,
  overall_score double precision not null,
  context_type text not null,
  location_name text not null,
  brew_details jsonb not null default '{}'::jsonb
);

insert into public.users (id) values ('${userID}');
insert into public.visits (
  id, user_id, drink_type, drink_subtype, caption, visibility,
  upload_state, ratings, overall_score, context_type, location_name, brew_details
) values (
  '${legacyVisitID}', '${userID}', 'Coffee', 'Legacy sip',
  'Existing captions remain readable.', 'private', 'complete',
  '{"Overall":4}'::jsonb, 4, 'home', 'Home', '{}'::jsonb
);
`)

const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260731143430_enforce_visit_caption_length.sql',
  'utf8',
)
await db.exec(migration)

const contract = await fs.readFile(
  repoPath + 'supabase/tests/visit_caption_length_contract.sql',
  'utf8',
)
await db.exec(contract)

const legacyCaption = await db.query(
  `select caption from public.visits where id = '${legacyVisitID}'`,
)
assert(
  legacyCaption.rows[0]?.caption === 'Existing captions remain readable.',
  'the migration changed an existing caption',
)

const constraint = await db.query(String.raw`
select pg_get_constraintdef(oid) definition
from pg_constraint
where conrelid = 'public.visits'::regclass
  and conname = 'visits_caption_maximum_length'
`)
assert(
  constraint.rows[0]?.definition?.includes('char_length(caption) <= 1000'),
  'the caption check constraint is missing or has the wrong limit',
)

console.log(
  'PGlite visit caption migration, legacy read, 1000-character insert/update, '
    + 'and 1001-character rejection checks passed',
)
