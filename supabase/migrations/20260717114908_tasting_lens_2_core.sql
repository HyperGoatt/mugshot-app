-- Tasting Lens 2.0 keeps the authored sensory record private and immutable.
-- Sharing is a separate, deliberately smaller projection. Preferences remain
-- editable; corrections are append-only so learning decisions are auditable.

create table public.visit_sensory_snapshots (
  visit_id uuid primary key,
  snapshot_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  schema_version integer not null,
  bundle_id text not null,
  bundle_content_version text not null,
  personalization_scope_id text not null,
  depth text not null check (depth in ('quick', 'guided', 'deep')),
  identity jsonb not null,
  responses jsonb not null,
  own_words text not null default '',
  personal_enjoyment numeric(2, 1),
  snapshot_payload jsonb not null,
  payload_hash text not null,
  created_at timestamptz not null,
  stored_at timestamptz not null default now(),
  constraint visit_sensory_snapshots_snapshot_id_unique unique (snapshot_id),
  constraint visit_sensory_snapshots_snapshot_owner_unique unique (snapshot_id, user_id),
  constraint visit_sensory_snapshots_projection_identity_unique unique (visit_id, snapshot_id, user_id),
  constraint visit_sensory_snapshots_visit_owner_fk
    foreign key (visit_id, user_id)
    references public.visits(id, user_id)
    on delete cascade
    deferrable initially deferred,
  constraint visit_sensory_snapshots_schema_version_positive check (schema_version > 0),
  constraint visit_sensory_snapshots_bundle_id_nonempty check (length(btrim(bundle_id)) > 0),
  constraint visit_sensory_snapshots_bundle_version_nonempty check (length(btrim(bundle_content_version)) > 0),
  constraint visit_sensory_snapshots_scope_nonempty check (length(btrim(personalization_scope_id)) > 0),
  constraint visit_sensory_snapshots_own_words_length check (char_length(own_words) <= 20000),
  constraint visit_sensory_snapshots_identity_object check (jsonb_typeof(identity) = 'object'),
  constraint visit_sensory_snapshots_responses_array check (jsonb_typeof(responses) = 'array'),
  constraint visit_sensory_snapshots_payload_object check (jsonb_typeof(snapshot_payload) = 'object'),
  constraint visit_sensory_snapshots_payload_hash_format check (payload_hash ~ '^[0-9a-f]{64}$'),
  constraint visit_sensory_snapshots_payload_id_matches check (
    (snapshot_payload ->> 'id')::uuid = snapshot_id
  ),
  constraint visit_sensory_snapshots_payload_schema_matches check (
    (snapshot_payload ->> 'schemaVersion')::integer = schema_version
  ),
  constraint visit_sensory_snapshots_payload_bundle_matches check (
    snapshot_payload ->> 'bundleID' = bundle_id
    and snapshot_payload ->> 'bundleContentVersion' = bundle_content_version
  ),
  constraint visit_sensory_snapshots_payload_scope_matches check (
    snapshot_payload ->> 'personalizationScopeID' = personalization_scope_id
  ),
  constraint visit_sensory_snapshots_payload_depth_matches check (
    snapshot_payload ->> 'depth' = depth
  ),
  constraint visit_sensory_snapshots_payload_identity_matches check (
    snapshot_payload -> 'identity' = identity
  ),
  constraint visit_sensory_snapshots_payload_responses_match check (
    snapshot_payload -> 'responses' = responses
  ),
  constraint visit_sensory_snapshots_payload_words_match check (
    coalesce(snapshot_payload ->> 'ownWords', '') = own_words
  ),
  constraint visit_sensory_snapshots_payload_enjoyment_matches check (
    (snapshot_payload ->> 'personalEnjoyment')::numeric is not distinct from personal_enjoyment
  ),
  constraint visit_sensory_snapshots_personal_enjoyment check (
    personal_enjoyment is null or (
      personal_enjoyment between 1 and 5
      and personal_enjoyment * 2 = trunc(personal_enjoyment * 2)
    )
  )
);

create index visit_sensory_snapshots_owner_history_idx
  on public.visit_sensory_snapshots(user_id, created_at desc, visit_id desc);
create index visit_sensory_snapshots_owner_scope_idx
  on public.visit_sensory_snapshots(user_id, personalization_scope_id, created_at desc);

-- A projection does not exist unless the owner explicitly elects to share it.
-- It intentionally cannot expose free-form first words or the complete answer trail.
create table public.visit_sensory_public_projections (
  visit_id uuid primary key,
  snapshot_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  schema_version integer not null default 1,
  bundle_id text not null,
  bundle_content_version text not null,
  depth text not null check (depth in ('quick', 'guided', 'deep')),
  personal_enjoyment numeric(2, 1),
  descriptor_ids text[] not null default '{}',
  dimension_ids text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint visit_sensory_public_projection_identity_fk
    foreign key (visit_id, snapshot_id, user_id)
    references public.visit_sensory_snapshots(visit_id, snapshot_id, user_id)
    on delete cascade,
  constraint visit_sensory_public_projection_schema_version_positive check (schema_version > 0),
  constraint visit_sensory_public_projection_bundle_nonempty check (length(btrim(bundle_id)) > 0),
  constraint visit_sensory_public_projection_bundle_version_nonempty check (length(btrim(bundle_content_version)) > 0),
  constraint visit_sensory_public_projection_descriptor_limit check (cardinality(descriptor_ids) <= 8),
  constraint visit_sensory_public_projection_dimension_limit check (cardinality(dimension_ids) <= 8),
  constraint visit_sensory_public_projection_descriptor_ids check (
    array_position(descriptor_ids, null) is null
    and array_to_string(descriptor_ids, ',')
      ~ '^(|descriptor\.[a-z0-9][a-z0-9_.-]{0,107}(,descriptor\.[a-z0-9][a-z0-9_.-]{0,107})*)$'
  ),
  constraint visit_sensory_public_projection_dimension_ids check (
    array_position(dimension_ids, null) is null
    and array_to_string(dimension_ids, ',')
      ~ '^(|(identity|appearance|aroma|taste|flavor|body|texture|astringency|finish|temperature_change|integration|balance|unexpected|personal_response)(,(identity|appearance|aroma|taste|flavor|body|texture|astringency|finish|temperature_change|integration|balance|unexpected|personal_response))*)$'
  ),
  constraint visit_sensory_public_projection_personal_enjoyment check (
    personal_enjoyment is null or (
      personal_enjoyment between 1 and 5
      and personal_enjoyment * 2 = trunc(personal_enjoyment * 2)
    )
  )
);

create table public.tasting_lens_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  schema_version integer not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  constraint tasting_lens_preferences_schema_version_positive check (schema_version > 0),
  constraint tasting_lens_preferences_payload_object check (jsonb_typeof(payload) = 'object')
);

create table public.tasting_lens_corrections (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  snapshot_id uuid not null,
  target_id text not null,
  scope_id text not null,
  reason text not null check (reason in ('not_useful', 'selected_by_mistake', 'not_relevant', 'other')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint tasting_lens_corrections_snapshot_owner_fk
    foreign key (snapshot_id, user_id)
    references public.visit_sensory_snapshots(snapshot_id, user_id)
    on delete cascade,
  constraint tasting_lens_corrections_target_nonempty check (length(btrim(target_id)) > 0),
  constraint tasting_lens_corrections_scope_nonempty check (length(btrim(scope_id)) > 0),
  constraint tasting_lens_corrections_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create index tasting_lens_corrections_owner_snapshot_idx
  on public.tasting_lens_corrections(user_id, snapshot_id, created_at desc);
