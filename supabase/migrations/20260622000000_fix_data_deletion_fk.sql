ALTER TABLE public.data_deletion_requests ADD CONSTRAINT fk_user_profile FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
