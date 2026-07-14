-- RLS and existing table grants are sufficient for the export. Run it with
-- caller privileges so even a future query mistake cannot bypass row policy.

alter function public.build_owner_data_export() security invoker;
