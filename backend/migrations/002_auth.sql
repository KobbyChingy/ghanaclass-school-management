-- Auth + staff management
--
-- We keep users in public so login can be by email only.
-- Each user belongs to exactly one school.

CREATE TABLE IF NOT EXISTS public.users (
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
	email text NOT NULL,
	password_hash text NOT NULL,
	full_name text NOT NULL,
	role text NOT NULL,
	is_active boolean NOT NULL DEFAULT true,
	created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email
	ON public.users (lower(email));

CREATE INDEX IF NOT EXISTS idx_users_school
	ON public.users (school_id);
