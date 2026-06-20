-- Migration: 20260618000000_otp_rate_limiting.sql

CREATE TABLE public.otp_attempts (
    email TEXT PRIMARY KEY,
    attempts INT DEFAULT 0,
    last_attempt_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    locked_until TIMESTAMP WITH TIME ZONE
);

-- Enable RLS but define no policies, denying all public direct access.
ALTER TABLE public.otp_attempts ENABLE ROW LEVEL SECURITY;

-- Check OTP Status
-- Returns JSON: { "allowed": boolean, "attempts_left": int, "locked_until": timestamp }
CREATE OR REPLACE FUNCTION public.check_otp_status(target_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rec RECORD;
BEGIN
    SELECT * INTO rec FROM public.otp_attempts WHERE email = target_email;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', true, 'attempts_left', 3);
    END IF;

    -- Check if locked and time has not expired
    IF rec.locked_until IS NOT NULL AND rec.locked_until > NOW() THEN
        RETURN jsonb_build_object('allowed', false, 'locked_until', rec.locked_until);
    END IF;

    -- If lock expired
    IF rec.locked_until IS NOT NULL AND rec.locked_until <= NOW() THEN
        RETURN jsonb_build_object('allowed', true, 'attempts_left', 3);
    END IF;

    RETURN jsonb_build_object('allowed', true, 'attempts_left', GREATEST(0, 3 - rec.attempts));
END;
$$;

-- Record OTP Attempt
-- Returns JSON: { "allowed": boolean, "attempts_left": int, "locked_until": timestamp }
CREATE OR REPLACE FUNCTION public.record_otp_attempt(target_email TEXT, is_success BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rec RECORD;
BEGIN
    -- Upsert the record if it doesn't exist
    INSERT INTO public.otp_attempts (email, attempts, last_attempt_at)
    VALUES (target_email, 0, NOW())
    ON CONFLICT (email) DO NOTHING;

    SELECT * INTO rec FROM public.otp_attempts WHERE email = target_email;

    -- If currently locked
    IF rec.locked_until IS NOT NULL AND rec.locked_until > NOW() THEN
        RETURN jsonb_build_object('allowed', false, 'locked_until', rec.locked_until);
    END IF;

    -- If lock expired, reset it
    IF rec.locked_until IS NOT NULL AND rec.locked_until <= NOW() THEN
        UPDATE public.otp_attempts SET attempts = 0, locked_until = NULL WHERE email = target_email;
        rec.attempts := 0;
        rec.locked_until := NULL;
    END IF;

    IF is_success THEN
        -- Success clears the attempts
        UPDATE public.otp_attempts SET attempts = 0, locked_until = NULL WHERE email = target_email;
        RETURN jsonb_build_object('allowed', true, 'attempts_left', 3);
    ELSE
        -- Failure increments attempts
        UPDATE public.otp_attempts 
        SET attempts = attempts + 1, last_attempt_at = NOW() 
        WHERE email = target_email
        RETURNING * INTO rec;

        -- If it reached 3 attempts, lock for 2 hours
        IF rec.attempts >= 3 THEN
            UPDATE public.otp_attempts 
            SET locked_until = NOW() + INTERVAL '2 hours' 
            WHERE email = target_email
            RETURNING * INTO rec;
            RETURN jsonb_build_object('allowed', false, 'locked_until', rec.locked_until);
        ELSE
            RETURN jsonb_build_object('allowed', true, 'attempts_left', 3 - rec.attempts);
        END IF;
    END IF;
END;
$$;
