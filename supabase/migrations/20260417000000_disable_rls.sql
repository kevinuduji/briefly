-- Drop all RLS policies and disable RLS on every table (demo build).

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

drop policy if exists "business_profiles_select_own" on public.business_profiles;
drop policy if exists "business_profiles_insert_own" on public.business_profiles;
drop policy if exists "business_profiles_update_own" on public.business_profiles;
drop policy if exists "business_profiles_delete_own" on public.business_profiles;

drop policy if exists "daily_logs_select_own" on public.daily_logs;
drop policy if exists "daily_logs_insert_own" on public.daily_logs;
drop policy if exists "daily_logs_update_own" on public.daily_logs;
drop policy if exists "daily_logs_delete_own" on public.daily_logs;

drop policy if exists "metric_snapshots_select_own" on public.metric_snapshots;
drop policy if exists "metric_snapshots_insert_own" on public.metric_snapshots;
drop policy if exists "metric_snapshots_update_own" on public.metric_snapshots;
drop policy if exists "metric_snapshots_delete_own" on public.metric_snapshots;

drop policy if exists "actions_select_own" on public.action_recommendations;
drop policy if exists "actions_insert_own" on public.action_recommendations;
drop policy if exists "actions_update_own" on public.action_recommendations;
drop policy if exists "actions_delete_own" on public.action_recommendations;

drop policy if exists "outcomes_select_own" on public.action_outcomes;
drop policy if exists "outcomes_insert_own" on public.action_outcomes;
drop policy if exists "outcomes_update_own" on public.action_outcomes;
drop policy if exists "outcomes_delete_own" on public.action_outcomes;

drop policy if exists "docs_select_own" on public.uploaded_documents;
drop policy if exists "docs_insert_own" on public.uploaded_documents;
drop policy if exists "docs_update_own" on public.uploaded_documents;
drop policy if exists "docs_delete_own" on public.uploaded_documents;

drop policy if exists "reports_select_own" on public.generated_reports;
drop policy if exists "reports_insert_own" on public.generated_reports;
drop policy if exists "reports_update_own" on public.generated_reports;
drop policy if exists "reports_delete_own" on public.generated_reports;

drop policy if exists "notif_select_own" on public.notification_tasks;
drop policy if exists "notif_insert_own" on public.notification_tasks;
drop policy if exists "notif_update_own" on public.notification_tasks;
drop policy if exists "notif_delete_own" on public.notification_tasks;

alter table public.profiles disable row level security;
alter table public.business_profiles disable row level security;
alter table public.daily_logs disable row level security;
alter table public.metric_snapshots disable row level security;
alter table public.action_recommendations disable row level security;
alter table public.action_outcomes disable row level security;
alter table public.uploaded_documents disable row level security;
alter table public.generated_reports disable row level security;
alter table public.notification_tasks disable row level security;
