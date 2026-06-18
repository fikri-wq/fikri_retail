-- Fungsi ini dipanggil oleh Edge Function create-admin
-- SECURITY DEFINER = berjalan sebagai superuser, bypass RLS sepenuhnya
CREATE OR REPLACE FUNCTION public.set_user_role_admin(target_user_id UUID, target_full_name TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET role = 'admin', full_name = target_full_name
  WHERE id = target_user_id;

  -- Jika belum ada row (trigger belum jalan), insert
  IF NOT FOUND THEN
    INSERT INTO public.profiles (id, full_name, role)
    VALUES (target_user_id, target_full_name, 'admin');
  END IF;
END;
$$;

-- Izinkan Edge Function (authenticated/service_role) memanggil fungsi ini
GRANT EXECUTE ON FUNCTION public.set_user_role_admin TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_role_admin TO service_role;
