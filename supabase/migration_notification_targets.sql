-- Migration: notification target tracking + images
--
-- Adds what ctet_content_admin.php's Notification tab needs for two new
-- features:
--   - `tap_data` (jsonb): the exact thing a notification pointed at
--     (test_set_id, bullet-revision duration, or subject+block_index) —
--     `tap_action` alone only said *which kind* of target, not *which
--     one*, so there was no way to know "have we already notified about
--     THIS specific test/duration/block" (used to sink already-notified
--     items to the bottom of their picker).
--   - `image_url` (text): the notification image actually sent (custom
--     upload, or the target's own logo used as a fallback) — shown as a
--     thumbnail in "Pehle Ki Notifications" history.
--
-- Also creates the `notification-images` public Storage bucket, same
-- shape as exam-logos/test-set-logos/question-images, for the custom
-- image upload.
--
-- Safe to run more than once.

alter table public.notification_log
  add column if not exists tap_data jsonb,
  add column if not exists image_url text;

insert into storage.buckets (id, name, public)
values ('notification-images', 'notification-images', true)
on conflict (id) do nothing;
