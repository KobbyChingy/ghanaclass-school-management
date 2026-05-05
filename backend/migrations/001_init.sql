-- GhanaClass backend starter schema
--
-- Tenancy model: schema-per-school.
--
-- public.* holds global registry and idempotency tracking.
-- Each school schema contains a change log (and later, the domain tables).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Global: school registry
CREATE TABLE IF NOT EXISTS public.schools (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	code text NOT NULL UNIQUE,
	name text NOT NULL,
	schema_name text NOT NULL UNIQUE,
	created_at timestamptz NOT NULL DEFAULT now()
);

-- Global: applied operations for idempotent sync push
CREATE TABLE IF NOT EXISTS public.applied_ops (
	op_id uuid PRIMARY KEY,
	school_schema text NOT NULL,
	device_id text NOT NULL,
	applied_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_applied_ops_school_time
	ON public.applied_ops(school_schema, applied_at DESC);

-- Helper: initialize a new school schema and its change log
-- Usage:
--   SELECT public.create_school_schema('school_001');
CREATE OR REPLACE FUNCTION public.create_school_schema(schema_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
	EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);
	EXECUTE format('
		CREATE TABLE IF NOT EXISTS %I.change_log (
			seq bigserial PRIMARY KEY,
			entity_type text NOT NULL,
			operation text NOT NULL,
			payload jsonb NOT NULL,
			changed_at timestamptz NOT NULL DEFAULT now()
		)
	', schema_name);
END;
$$;
