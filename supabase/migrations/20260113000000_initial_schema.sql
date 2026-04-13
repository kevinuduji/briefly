-- Briefly V1: core schema + RLS + storage buckets

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  business_name text,
  business_type text,
  business_description text,
  primary_goal text,
  notifications_enabled boolean not null default true,
  spreadsheets_or_documents_note text
);

create table if not exists public.business_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  business_type text,
  revenue_model_summary text,
  operating_notes text,
  recurring_themes jsonb not null default '[]'::jsonb,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.daily_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  log_date date not null default (timezone('utc', now()))::date,
  raw_transcript text,
  cleaned_summary text,
  structured_data jsonb not null default '{}'::jsonb,
  confidence_notes text,
  source_type text not null default 'voice' check (source_type in ('voice', 'uploaded_file', 'mixed')),
  status text not null default 'draft' check (status in ('draft', 'confirmed', 'processed')),
  audio_storage_path text,
  local_draft_id text
);

create index if not exists daily_logs_user_log_date_idx on public.daily_logs (user_id, log_date desc);

create table if not exists public.metric_snapshots (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.daily_logs (id) on delete cascade,
  traffic integer,
  sales_count integer,
  conversion_estimate numeric,
  inventory_status text,
  inventory_risk_level text,
  trend_notes text,
  metric_confidence text
);

create table if not exists public.action_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_id uuid references public.daily_logs (id) on delete set null,
  title text not null,
  reason text,
  priority text,
  category text,
  expected_impact text,
  follow_up_date date,
  status text not null default 'pending' check (status in ('pending', 'done', 'skipped', 'snoozed')),
  created_at timestamptz not null default now()
);

create index if not exists action_recommendations_user_status_idx on public.action_recommendations (user_id, status);

create table if not exists public.action_outcomes (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null references public.action_recommendations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  user_feedback text,
  outcome_summary text,
  perceived_effect text,
  optional_metric_delta jsonb
);

create table if not exists public.uploaded_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  file_type text,
  storage_path text not null,
  extracted_summary text,
  parsed_structured_data jsonb not null default '{}'::jsonb,
  processing_status text not null default 'pending' check (processing_status in ('pending', 'processing', 'done', 'failed'))
);

create table if not exists public.generated_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  report_type text not null,
  title text,
  storage_path text not null,
  related_log_ids uuid[] not null default '{}'::uuid[]
);

create table if not exists public.notification_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null,
  scheduled_for timestamptz not null,
  related_action_id uuid references public.action_recommendations (id) on delete set null,
  related_log_id uuid references public.daily_logs (id) on delete set null,
  status text not null default 'scheduled' check (status in ('scheduled', 'sent', 'cancelled', 'failed'))
);

create index if not exists notification_tasks_user_scheduled_idx on public.notification_tasks (user_id, scheduled_for);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists business_profiles_set_updated_at on public.business_profiles;
create trigger business_profiles_set_updated_at
before update on public.business_profiles
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.business_profiles enable row level security;
alter table public.daily_logs enable row level security;
alter table public.metric_snapshots enable row level security;
alter table public.action_recommendations enable row level security;
alter table public.action_outcomes enable row level security;
alter table public.uploaded_documents enable row level security;
alter table public.generated_reports enable row level security;
alter table public.notification_tasks enable row level security;

create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

create policy "business_profiles_select_own" on public.business_profiles for select using (auth.uid() = user_id);
create policy "business_profiles_insert_own" on public.business_profiles for insert with check (auth.uid() = user_id);
create policy "business_profiles_update_own" on public.business_profiles for update using (auth.uid() = user_id);
create policy "business_profiles_delete_own" on public.business_profiles for delete using (auth.uid() = user_id);

create policy "daily_logs_select_own" on public.daily_logs for select using (auth.uid() = user_id);
create policy "daily_logs_insert_own" on public.daily_logs for insert with check (auth.uid() = user_id);
create policy "daily_logs_update_own" on public.daily_logs for update using (auth.uid() = user_id);
create policy "daily_logs_delete_own" on public.daily_logs for delete using (auth.uid() = user_id);

create policy "metric_snapshots_select_own" on public.metric_snapshots for select
  using (exists (select 1 from public.daily_logs l where l.id = metric_snapshots.log_id and l.user_id = auth.uid()));
create policy "metric_snapshots_insert_own" on public.metric_snapshots for insert
  with check (exists (select 1 from public.daily_logs l where l.id = metric_snapshots.log_id and l.user_id = auth.uid()));
create policy "metric_snapshots_update_own" on public.metric_snapshots for update
  using (exists (select 1 from public.daily_logs l where l.id = metric_snapshots.log_id and l.user_id = auth.uid()));
create policy "metric_snapshots_delete_own" on public.metric_snapshots for delete
  using (exists (select 1 from public.daily_logs l where l.id = metric_snapshots.log_id and l.user_id = auth.uid()));

create policy "actions_select_own" on public.action_recommendations for select using (auth.uid() = user_id);
create policy "actions_insert_own" on public.action_recommendations for insert with check (auth.uid() = user_id);
create policy "actions_update_own" on public.action_recommendations for update using (auth.uid() = user_id);
create policy "actions_delete_own" on public.action_recommendations for delete using (auth.uid() = user_id);

create policy "outcomes_select_own" on public.action_outcomes for select using (auth.uid() = user_id);
create policy "outcomes_insert_own" on public.action_outcomes for insert with check (auth.uid() = user_id);
create policy "outcomes_update_own" on public.action_outcomes for update using (auth.uid() = user_id);
create policy "outcomes_delete_own" on public.action_outcomes for delete using (auth.uid() = user_id);

create policy "docs_select_own" on public.uploaded_documents for select using (auth.uid() = user_id);
create policy "docs_insert_own" on public.uploaded_documents for insert with check (auth.uid() = user_id);
create policy "docs_update_own" on public.uploaded_documents for update using (auth.uid() = user_id);
create policy "docs_delete_own" on public.uploaded_documents for delete using (auth.uid() = user_id);

create policy "reports_select_own" on public.generated_reports for select using (auth.uid() = user_id);
create policy "reports_insert_own" on public.generated_reports for insert with check (auth.uid() = user_id);
create policy "reports_update_own" on public.generated_reports for update using (auth.uid() = user_id);
create policy "reports_delete_own" on public.generated_reports for delete using (auth.uid() = user_id);

create policy "notif_select_own" on public.notification_tasks for select using (auth.uid() = user_id);
create policy "notif_insert_own" on public.notification_tasks for insert with check (auth.uid() = user_id);
create policy "notif_update_own" on public.notification_tasks for update using (auth.uid() = user_id);
create policy "notif_delete_own" on public.notification_tasks for delete using (auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into storage.buckets (id, name, public)
values
  ('briefly-audio', 'briefly-audio', false),
  ('briefly-documents', 'briefly-documents', false),
  ('briefly-reports', 'briefly-reports', false)
on conflict (id) do nothing;

create policy "briefly_audio_select_own"
on storage.objects for select to authenticated
using (bucket_id = 'briefly-audio' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_audio_insert_own"
on storage.objects for insert to authenticated
with check (bucket_id = 'briefly-audio' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_audio_update_own"
on storage.objects for update to authenticated
using (bucket_id = 'briefly-audio' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_audio_delete_own"
on storage.objects for delete to authenticated
using (bucket_id = 'briefly-audio' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_docs_select_own"
on storage.objects for select to authenticated
using (bucket_id = 'briefly-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_docs_insert_own"
on storage.objects for insert to authenticated
with check (bucket_id = 'briefly-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_docs_update_own"
on storage.objects for update to authenticated
using (bucket_id = 'briefly-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_docs_delete_own"
on storage.objects for delete to authenticated
using (bucket_id = 'briefly-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_reports_select_own"
on storage.objects for select to authenticated
using (bucket_id = 'briefly-reports' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_reports_insert_own"
on storage.objects for insert to authenticated
with check (bucket_id = 'briefly-reports' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_reports_update_own"
on storage.objects for update to authenticated
using (bucket_id = 'briefly-reports' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "briefly_reports_delete_own"
on storage.objects for delete to authenticated
using (bucket_id = 'briefly-reports' and (storage.foldername(name))[1] = auth.uid()::text);
