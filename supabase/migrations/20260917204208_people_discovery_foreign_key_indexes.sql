-- Support foreign-key maintenance without widening access to private People
-- discovery state.

create index discovery_suppressions_candidate_idx
  on private.discovery_suppressions (candidate_id);

create index friend_request_attributions_invite_idx
  on private.friend_request_attributions (invite_id)
  where invite_id is not null;
