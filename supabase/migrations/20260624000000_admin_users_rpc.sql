-- HerbaScan: Add get_admin_users RPC for Admin Portal to see email_confirmed_at
-- Run in Supabase Dashboard → SQL Editor to enable Email Verified status in the Admin User Management screen.

CREATE OR REPLACE FUNCTION public.get_admin_users()
RETURNS TABLE (
  id uuid,
  email text,
  role text,
  is_active boolean,
  created_at timestamptz,
  suspension_reason text,
  force_verified_notice boolean,
  role_change_notice boolean,
  email_confirmed_at timestamptz
) AS $$
BEGIN
  -- Verify admin
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT 
    p.id,
    p.email,
    p.role,
    p.is_active,
    p.created_at,
    p.suspension_reason,
    p.force_verified_notice,
    p.role_change_notice,
    au.email_confirmed_at
  FROM public.profiles p
  LEFT JOIN auth.users au ON au.id = p.id
  ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
