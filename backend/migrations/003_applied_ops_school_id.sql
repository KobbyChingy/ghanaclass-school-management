ALTER TABLE public.applied_ops
  ADD COLUMN IF NOT EXISTS school_id uuid;

UPDATE public.applied_ops ao
SET school_id = s.id
FROM public.schools s
WHERE ao.school_id IS NULL
  AND ao.school_schema = s.schema_name;

CREATE INDEX IF NOT EXISTS idx_applied_ops_school_id_time
  ON public.applied_ops(school_id, applied_at DESC);