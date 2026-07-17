create index tasting_lens_corrections_snapshot_owner_idx
  on public.tasting_lens_corrections(snapshot_id, user_id);
create index visit_sensory_public_projection_identity_idx
  on public.visit_sensory_public_projections(visit_id, snapshot_id, user_id);
create index visit_sensory_public_projection_owner_idx
  on public.visit_sensory_public_projections(user_id, created_at desc, visit_id);
create index visit_sensory_snapshots_visit_owner_idx
  on public.visit_sensory_snapshots(visit_id, user_id);
