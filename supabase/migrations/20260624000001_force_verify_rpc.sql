-- HerbaScan: Admin-only RPC to directly set email_confirmed_at on auth.users
-- This is 100% reliable unlike the JS client updateUserById method which can
-- fail to backfill email_confirmed_at on older accounts.
-- Only callable by users with role = 'admin' in public.profiles.

CREATE OR REPLACE FUNCTION public.admin_force_verify_email(target_user_id UUID)
RETURNS void AS $$
BEGIN
  -- Verify caller is admin
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Directly set email_confirmed_at on auth.users — guaranteed to work
  UPDATE auth.users
  SET email_confirmed_at = NOW(),
      updated_at = NOW()
  WHERE id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
