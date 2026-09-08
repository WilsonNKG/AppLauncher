-- Central NKG launcher database.
-- Keep business tables for logistics and waterpark in their own projects.

create table if not exists public.launcher_apps (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text not null default '',
  launch_url text not null,
  status text not null default 'active' check (status in ('active', 'paused')),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.nkg_roles (
  id uuid primary key default gen_random_uuid(),
  app_id uuid references public.launcher_apps(id) on delete cascade,
  name text not null unique,
  description text not null default ''
);

-- For existing installations, roles can be migrated to app-specific roles.
alter table public.nkg_roles add column if not exists app_id uuid
  references public.launcher_apps(id) on delete cascade;
alter table public.nkg_roles drop constraint if exists nkg_roles_name_key;
alter table public.nkg_roles drop constraint if exists nkg_roles_app_name_unique;
alter table public.nkg_roles add constraint nkg_roles_app_name_unique
  unique (app_id, name);

create table if not exists public.nkg_permissions (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references public.launcher_apps(id) on delete cascade,
  permission_key text not null,
  description text not null default '',
  unique (app_id, permission_key)
);

create table if not exists public.nkg_user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.nkg_roles(id) on delete cascade,
  primary key (user_id, role_id)
);

create table if not exists public.nkg_role_permissions (
  role_id uuid not null references public.nkg_roles(id) on delete cascade,
  permission_id uuid not null references public.nkg_permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create table if not exists public.nkg_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.nkg_bug_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  app_id uuid references public.launcher_apps(id) on delete set null,
  title text not null,
  description text not null,
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'critical')),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.nkg_notifications enable row level security;
alter table public.nkg_bug_reports enable row level security;

create or replace function public.get_my_notifications()
returns table (id uuid, title text, body text, read_at timestamptz, created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select n.id, n.title, n.body, n.read_at, n.created_at
  from public.nkg_notifications n
  where n.user_id = auth.uid() or n.user_id is null
  order by n.created_at desc
  limit 50;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.nkg_notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and (user_id = auth.uid() or user_id is null);
$$;

create or replace function public.create_bug_report(
  p_title text, p_description text, p_app_id uuid default null, p_priority text default 'normal'
)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  if length(trim(p_title)) < 3 or length(trim(p_description)) < 10 then
    raise exception 'Please provide a title and a description of at least 10 characters';
  end if;
  insert into public.nkg_bug_reports(reporter_id, app_id, title, description, priority)
  values (auth.uid(), p_app_id, trim(p_title), trim(p_description), p_priority)
  returning id into new_id;
  insert into public.nkg_notifications(user_id, title, body)
  select ur.user_id, 'New bug report', trim(p_title)
  from public.nkg_user_roles ur
  join public.nkg_roles r on r.id = ur.role_id
  where r.name = 'Master' and ur.user_id <> auth.uid();
  return new_id;
end;
$$;

create or replace function public.get_bug_reports_for_master()
returns table (id uuid, reporter_email text, app_name text, title text, description text,
  priority text, status text, created_at timestamptz)
language plpgsql security definer set search_path = public stable as $$
begin
  if not exists (
    select 1 from public.nkg_user_roles ur join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid() and r.name = 'Master'
  ) then raise exception 'Only Master users can view bug reports'; end if;
  return query
  select b.id, u.email::text, a.name, b.title, b.description,
    b.priority, b.status, b.created_at
  from public.nkg_bug_reports b
  join auth.users u on u.id = b.reporter_id
  left join public.launcher_apps a on a.id = b.app_id
  order by b.created_at desc;
end;
$$;

create or replace function public.update_bug_report_status(p_bug_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.nkg_user_roles ur join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid() and r.name = 'Master'
  ) then raise exception 'Only Master users can update bug reports'; end if;
  update public.nkg_bug_reports
  set status = p_status, updated_at = now()
  where id = p_bug_id and p_status in ('open', 'in_progress', 'resolved');
end;
$$;

revoke all on function public.get_my_notifications() from public;
revoke all on function public.mark_notification_read(uuid) from public;
revoke all on function public.create_bug_report(text, text, uuid, text) from public;
revoke all on function public.get_bug_reports_for_master() from public;
revoke all on function public.update_bug_report_status(uuid, text) from public;
grant execute on function public.get_my_notifications() to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.create_bug_report(text, text, uuid, text) to authenticated;
grant execute on function public.get_bug_reports_for_master() to authenticated;
grant execute on function public.update_bug_report_status(uuid, text) to authenticated;

-- Human-readable view for administrators. The relationship tables keep UUIDs,
-- while this view makes it easy to understand each user's effective access.
create or replace view public.nkg_staff_access_overview as
select
  u.id as user_id,
  u.email as user_email,
  coalesce(r.name, 'No role assigned') as role,
  case
    when r.id is null then 'No app access'
    else coalesce(a.name, 'All applications')
  end as app_access,
  coalesce(
    string_agg(distinct p.permission_key, ', ' order by p.permission_key),
    'No permissions'
  ) as permissions
from auth.users u
left join public.nkg_user_roles ur on ur.user_id = u.id
left join public.nkg_roles r on r.id = ur.role_id
left join public.launcher_apps a on a.id = r.app_id
left join public.nkg_role_permissions rp on rp.role_id = r.id
left join public.nkg_permissions p on p.id = rp.permission_id
group by u.id, u.email, r.id, r.name, a.name
order by u.email, a.name nulls first, r.name;

revoke all on public.nkg_staff_access_overview from anon, authenticated;

alter table public.launcher_apps enable row level security;
alter table public.nkg_roles enable row level security;
alter table public.nkg_permissions enable row level security;
alter table public.nkg_user_roles enable row level security;
alter table public.nkg_role_permissions enable row level security;

create or replace function public.get_my_launcher_apps()
returns table (
  app_id uuid,
  app_name text,
  description text,
  launch_url text,
  status text,
  permissions jsonb
)
language sql
security definer
set search_path = public
stable
as $$
  select
    a.id,
    a.name,
    a.description,
    a.launch_url,
    a.status,
    coalesce(
      jsonb_agg(distinct p.permission_key) filter (where p.permission_key is not null),
      '[]'::jsonb
    ) as permissions
  from public.launcher_apps a
  join public.nkg_permissions p on p.app_id = a.id
  join public.nkg_role_permissions rp on rp.permission_id = p.id
  join public.nkg_user_roles ur on ur.role_id = rp.role_id
  where ur.user_id = auth.uid()
  group by a.id, a.name, a.description, a.launch_url, a.status, a.sort_order
  order by a.sort_order, a.name;
$$;

revoke all on function public.get_my_launcher_apps() from public;
grant execute on function public.get_my_launcher_apps() to authenticated;

create or replace function public.get_all_staff_for_admin()
returns table (
  user_id uuid,
  email text,
  created_at timestamptz,
  roles jsonb
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not exists (
    select 1
    from public.nkg_user_roles ur
    join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.name = 'Master'
  ) then
    raise exception 'Only administrators can view staff';
  end if;

  return query
  select
    u.id,
    u.email::text,
    u.created_at,
    coalesce(
      jsonb_agg(
        distinct jsonb_build_object(
          'role_id', r.id,
          'role_name', r.name,
          'app_name', a.name
        )
      ) filter (where r.id is not null),
      '[]'::jsonb
    ) as roles
  from auth.users u
  left join public.nkg_user_roles ur on ur.user_id = u.id
  left join public.nkg_roles r on r.id = ur.role_id
  left join public.launcher_apps a on a.id = r.app_id
  group by u.id, u.email, u.created_at
  order by u.created_at desc;
end;
$$;

revoke all on function public.get_all_staff_for_admin() from public;
grant execute on function public.get_all_staff_for_admin() to authenticated;

drop function if exists public.get_all_roles_for_admin();

create or replace function public.get_all_roles_for_admin()
returns table (
  role_id uuid,
  app_id uuid,
  app_name text,
  role_name text,
  description text,
  app_access text,
  permission_keys jsonb
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not exists (
    select 1
    from public.nkg_user_roles ur
    join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.name = 'Master'
  ) then
    raise exception 'Only administrators can view roles';
  end if;

  return query
  select
    r.id,
    r.app_id,
    a.name,
    r.name,
    r.description,
    coalesce(
      string_agg(distinct access_app.name, ', ' order by access_app.name),
      'No app access'
    ),
    coalesce(
      jsonb_agg(distinct permission.permission_key)
        filter (where permission.permission_key is not null),
      '[]'::jsonb
    )
  from public.nkg_roles r
  left join public.launcher_apps a on a.id = r.app_id
  left join public.nkg_role_permissions rp on rp.role_id = r.id
  left join public.nkg_permissions permission on permission.id = rp.permission_id
  left join public.launcher_apps access_app on access_app.id = permission.app_id
  group by r.id, r.app_id, a.name, r.name, r.description
  order by a.name nulls first, r.name;
end;
$$;

revoke all on function public.get_all_roles_for_admin() from public;
grant execute on function public.get_all_roles_for_admin() to authenticated;

drop function if exists public.create_custom_role_for_admin(uuid, text, text);

create or replace function public.create_custom_role_for_admin(
  p_app_id uuid,
  p_role_name text,
  p_description text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_role_id uuid;
begin
  if not exists (
    select 1 from public.nkg_user_roles ur
    join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid() and r.name = 'Master'
  ) then
    raise exception 'Only administrators can create roles';
  end if;

  if p_app_id is null or not exists (
    select 1 from public.launcher_apps where id = p_app_id
  ) then
    raise exception 'A valid application is required';
  end if;

  insert into public.nkg_roles (app_id, name, description)
  values (p_app_id, trim(p_role_name), trim(coalesce(p_description, '')))
  returning id into new_role_id;
  return new_role_id;
end;
$$;

revoke all on function public.create_custom_role_for_admin(uuid, text, text) from public;
grant execute on function public.create_custom_role_for_admin(uuid, text, text) to authenticated;

drop function if exists public.set_role_permissions_for_admin(uuid, text[]);

create or replace function public.set_role_permissions_for_admin(
  p_role_id uuid,
  p_permission_keys text[]
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.nkg_user_roles ur
    join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid() and r.name = 'Master'
  ) then
    raise exception 'Only administrators can edit permissions';
  end if;

  delete from public.nkg_role_permissions where role_id = p_role_id;
  insert into public.nkg_role_permissions (role_id, permission_id)
  select p_role_id, p.id
  from public.nkg_permissions p
  join public.nkg_roles r on r.id = p_role_id and r.app_id = p.app_id
  where p.permission_key = any(coalesce(p_permission_keys, array[]::text[]));
  return true;
end;
$$;

revoke all on function public.set_role_permissions_for_admin(uuid, text[]) from public;
grant execute on function public.set_role_permissions_for_admin(uuid, text[]) to authenticated;

create or replace function public.set_user_roles_for_admin(
  p_user_id uuid,
  p_role_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_count integer;
begin
  if not exists (
    select 1
    from public.nkg_user_roles ur
    join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.name = 'Master'
  ) then
    raise exception 'Only administrators can change staff access';
  end if;

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'User does not exist';
  end if;

  select count(distinct r.id)::integer
  into requested_count
  from public.nkg_roles r
  where r.id = any(coalesce(p_role_ids, '{}'::uuid[]));

  if requested_count <> coalesce(array_length(p_role_ids, 1), 0) then
    raise exception 'One or more roles do not exist';
  end if;

  if p_user_id = auth.uid()
     and not exists (
       select 1
       from public.nkg_roles r
       where r.id = any(coalesce(p_role_ids, '{}'::uuid[]))
         and r.name = 'Master'
     ) then
    raise exception 'You cannot remove your own Master access';
  end if;

  delete from public.nkg_user_roles where user_id = p_user_id;

  insert into public.nkg_user_roles (user_id, role_id)
  select p_user_id, r.id
  from public.nkg_roles r
  where r.id = any(coalesce(p_role_ids, '{}'::uuid[]));
end;
$$;

revoke all on function public.set_user_roles_for_admin(uuid, uuid[]) from public;
grant execute on function public.set_user_roles_for_admin(uuid, uuid[]) to authenticated;

create or replace function public.get_all_launcher_apps_for_admin()
returns table (
  app_id uuid,
  app_name text,
  description text,
  launch_url text,
  status text,
  permissions jsonb
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not exists (
    select 1
    from public.nkg_user_roles ur
    join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.name = 'Master'
  ) then
    raise exception 'Only administrators can manage applications';
  end if;

  return query
  select
    a.id,
    a.name,
    a.description,
    a.launch_url,
    a.status,
    coalesce(
      jsonb_agg(distinct p.permission_key)
        filter (where p.permission_key is not null),
      '[]'::jsonb
    )
  from public.launcher_apps a
  left join public.nkg_permissions p on p.app_id = a.id
  group by a.id, a.name, a.description, a.launch_url, a.status, a.sort_order
  order by a.sort_order, a.name;
end;
$$;

drop function if exists public.set_launcher_app_status(uuid, text);

create or replace function public.set_launcher_app_status(
  p_app_id uuid,
  p_status text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_status not in ('active', 'paused') then
    raise exception 'Invalid application status';
  end if;

  if not exists (
    select 1
    from public.nkg_user_roles ur
    join public.nkg_roles r on r.id = ur.role_id
    where ur.user_id = auth.uid()
      and r.name = 'Master'
  ) then
    raise exception 'Only administrators can change application status';
  end if;

  update public.launcher_apps
  set status = p_status
  where id = p_app_id;

  return true;
end;
$$;

revoke all on function public.get_all_launcher_apps_for_admin() from public;
grant execute on function public.get_all_launcher_apps_for_admin() to authenticated;
revoke all on function public.set_launcher_app_status(uuid, text) from public;
grant execute on function public.set_launcher_app_status(uuid, text) to authenticated;

-- Example seed data. Replace launch URLs with your real deployments.
insert into public.launcher_apps (name, slug, description, launch_url, sort_order)
values
  ('NKG Logistics', 'logistics', 'Logistics, inventory, purchasing, and work orders.', 'https://logistics.nkg.app', 10),
  ('Waterpark', 'waterpark', 'Tickets, sales, QR scanning, staff, and reports.', 'https://waterpark.nkg.app', 20),
  ('GOR', 'gor', 'General operations and company-wide workflows.', 'https://gor.nkg.app', 30),
  ('Finance', 'finance', 'Financial operations, approvals, and reporting.', 'https://finance.nkg.app', 40),
  ('HR', 'hr', 'People, attendance, leave, and HR administration.', 'https://hr.nkg.app', 50),
  ('Marketing', 'marketing', 'Campaigns, content, brand, and marketing operations.', 'https://marketing.nkg.app', 60),
  ('Report', 'report', 'Cross-application reporting and business insights.', 'https://report.nkg.app', 70),
  ('Legal', 'legal', 'Contracts, compliance, cases, and legal workflows.', 'https://legal.nkg.app', 80)
on conflict (slug) do nothing;

insert into public.nkg_permissions (app_id, permission_key, description)
select a.id, v.permission_key, v.description
from public.launcher_apps a
cross join (values
  ('logistics', 'logistics.access', 'Open NKG Logistics'),
  ('waterpark', 'waterpark.access', 'Open Waterpark'),
  ('gor', 'gor.access', 'Open GOR'),
  ('finance', 'finance.access', 'Open Finance'),
  ('hr', 'hr.access', 'Open HR'),
  ('marketing', 'marketing.access', 'Open Marketing'),
  ('report', 'report.access', 'Open Report'),
  ('legal', 'legal.access', 'Open Legal')
) as v(slug, permission_key, description)
where a.slug = v.slug
on conflict (app_id, permission_key) do nothing;

insert into public.nkg_roles (name, description)
select 'Master', 'Full access to the launcher and every application'
where not exists (
  select 1 from public.nkg_roles
  where app_id is null and name = 'Master'
);

-- Migrate users from the previous global Admin role to Master.
insert into public.nkg_user_roles (user_id, role_id)
select ur.user_id, master.id
from public.nkg_user_roles ur
join public.nkg_roles old_role on old_role.id = ur.role_id
cross join public.nkg_roles master
where old_role.name = 'Admin'
  and old_role.app_id is null
  and master.name = 'Master'
  and master.app_id is null
on conflict do nothing;

delete from public.nkg_roles
where name = 'Admin' and app_id is null;

insert into public.nkg_roles (name, description)
select v.role_name, v.description
from (values
  ('Director', 'Cross-application access without launcher administration'),
  ('IT', 'Technical support and platform operations'),
  ('Finance', 'Financial workflows and oversight'),
  ('Accounting', 'Accounting operations and financial records'),
  ('Legal', 'Legal workflows and compliance records'),
  ('Admin', 'Administrative operations and staff coordination'),
  ('Manager', 'Management workflows and approvals'),
  ('Management', 'Access to the management workspace')
) as v(role_name, description)
where not exists (
  select 1 from public.nkg_roles r
  where r.app_id is null and r.name = v.role_name
);

-- Logistics roles are application-specific. Other application role catalogs
-- can be added later without changing the launcher authorization model.
insert into public.nkg_roles (app_id, name, description)
select a.id, v.role_name, v.description
from public.launcher_apps a
join (values
  ('Master', 'Full access within Logistics'),
  ('Director', 'Director-level access within Logistics'),
  ('Manager', 'Manager-level access within Logistics'),
  ('Purchasing', 'Purchasing access within Logistics'),
  ('Logistics', 'Operational logistics access')
) as v(role_name, description) on a.slug = 'logistics'
on conflict (app_id, name) do nothing;

insert into public.nkg_role_permissions (role_id, permission_id)
select r.id, p.id
from public.nkg_roles r
cross join public.nkg_permissions p
where r.name in ('Master', 'Director')
on conflict do nothing;

insert into public.nkg_role_permissions (role_id, permission_id)
select r.id, p.id
from public.nkg_roles r
join public.nkg_permissions p on (
  r.name = 'Multi_Staff'
  or (r.name = 'WP_Staff' and p.permission_key = 'waterpark.access')
  or (r.name = 'Logis_Staff' and p.permission_key = 'logistics.access')
)
where r.name in ('WP_Staff', 'Logis_Staff', 'Multi_Staff')
on conflict do nothing;

insert into public.nkg_role_permissions (role_id, permission_id)
select r.id, p.id
from public.nkg_roles r
join public.launcher_apps a on a.id = r.app_id and a.slug = 'logistics'
join public.nkg_permissions p on p.app_id = a.id
where r.name in ('Master', 'Director', 'Manager', 'Purchasing', 'Logistics')
  and p.permission_key = 'logistics.access'
on conflict do nothing;

-- Assign the first admin manually after creating the user:
-- insert into public.nkg_user_roles (user_id, role_id)
-- select 'AUTH_USER_UUID', id from public.nkg_roles where name = 'Master';

-- Secure one-time handoff from the launcher to a child application.
-- The child application must validate this ticket before showing its UI.
create table if not exists public.nkg_launcher_tickets (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  app_id uuid not null references public.launcher_apps(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '2 minutes'),
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists nkg_launcher_tickets_expiry_idx
  on public.nkg_launcher_tickets (expires_at);

alter table public.nkg_launcher_tickets enable row level security;

create or replace function public.create_launcher_ticket(p_app_slug text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text := encode(gen_random_bytes(32), 'hex');
  v_app_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select a.id into v_app_id
  from public.launcher_apps a
  where a.slug = p_app_slug and a.status = 'active';

  if v_app_id is null or not exists (
    select 1
    from public.nkg_user_roles ur
    join public.nkg_role_permissions rp on rp.role_id = ur.role_id
    join public.nkg_permissions p on p.id = rp.permission_id
    where ur.user_id = auth.uid()
      and p.app_id = v_app_id
      and p.permission_key = p_app_slug || '.access'
  ) then
    raise exception 'Application access denied';
  end if;

  insert into public.nkg_launcher_tickets (token, user_id, app_id)
  values (v_token, auth.uid(), v_app_id);

  return v_token;
end;
$$;

create or replace function public.consume_launcher_ticket(
  p_ticket text,
  p_app_slug text
)
returns table (user_id uuid, user_email text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  update public.nkg_launcher_tickets t
  set used_at = now()
  where t.token = trim(p_ticket)
    and t.used_at is null
    and t.expires_at > now()
    and t.app_id = (
      select a.id from public.launcher_apps a
      where a.slug = p_app_slug and a.status = 'active'
    )
  returning t.user_id into v_user_id;

  if v_user_id is null then
    return;
  end if;

  return query
  select u.id, u.email::text
  from auth.users u
  where u.id = v_user_id;
end;
$$;

revoke all on function public.create_launcher_ticket(text) from public;
grant execute on function public.create_launcher_ticket(text) to authenticated;
revoke all on function public.consume_launcher_ticket(text, text) from public;
grant execute on function public.consume_launcher_ticket(text, text) to anon, authenticated;
