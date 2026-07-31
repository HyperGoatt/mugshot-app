alter table public.visits
  drop constraint if exists visits_caption_maximum_length;

alter table public.visits
  add constraint visits_caption_maximum_length
  check (char_length(caption) <= 1000);
