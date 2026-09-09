-- Wesley Hall module for the shared GMCT Management System Supabase project.
-- Wesley Hall objects use a wesley_ prefix to avoid collisions with other GMCT modules.

create schema if not exists wesley_private;
revoke all on schema wesley_private from public, anon, authenticated;
create sequence if not exists public.wesley_booking_ref_seq start 1;

create table if not exists public.wesley_staff_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'booking_officer' check (role in ('admin','manager','booking_officer')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.wesley_organization_settings (
  id smallint primary key default 1 check (id = 1),
  hall_name text not null default 'WESLEY HALL',
  church_name text not null default 'THE METHODIST CHURCH OF GHANA - TORONTO CIRCUIT',
  address text not null default '69 MILVAN DR., NORTH YORK, ONTARIO. M9L 1Y8',
  phone text not null default '(416) 901 5900',
  email text not null default 'info@gmct-ca.org',
  manager_name text not null default '',
  manager_title text not null default 'Hall Manager / Authorized Officer',
  manager_signature_path text,
  auto_include_manager_signature boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.wesley_rental_settings (
  id smallint primary key default 1 check (id = 1),
  standard_rental_hours integer not null default 6 check (standard_rental_hours > 0),
  setup_minutes_before integer not null default 120 check (setup_minutes_before >= 0),
  cleanup_minutes_after integer not null default 60 check (cleanup_minutes_after >= 0),
  earliest_access time not null default '08:00',
  latest_vacate time not null default '00:00',
  extra_hour_rate numeric(10,2) not null default 0 check (extra_hour_rate >= 0),
  booking_deposit_percent numeric(5,2) not null default 50 check (booking_deposit_percent between 0 and 100),
  damage_deposit_amount numeric(10,2) not null default 500 check (damage_deposit_amount >= 0),
  charge_setup_time boolean not null default false,
  charge_cleanup_time boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.wesley_hall_spaces (
  id text primary key,
  name text not null unique,
  conflict_group text not null default 'main-hall',
  base_rate numeric(10,2) not null default 0 check (base_rate >= 0),
  capacity integer check (capacity is null or capacity > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wesley_services (
  id text primary key,
  name text not null unique,
  pricing_type text not null default 'flat' check (pricing_type in ('flat','hourly','per_unit')),
  price numeric(10,2) not null default 0 check (price >= 0),
  active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wesley_rental_terms (
  id text primary key,
  term_text text not null,
  display_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wesley_bookings (
  id uuid primary key default gen_random_uuid(),
  reference_number text not null unique,
  client_name text not null,
  client_address text not null default '',
  phone text not null default '',
  email text not null default '',
  event_date date not null,
  event_start timestamp not null,
  event_end timestamp not null,
  access_start timestamp not null,
  vacate_end timestamp not null,
  event_details text not null default '',
  guest_count integer not null default 0 check (guest_count >= 0),
  hall_space_id text not null references public.wesley_hall_spaces(id),
  hall_charge numeric(10,2) not null default 0 check (hall_charge >= 0),
  extra_time_charge numeric(10,2) not null default 0 check (extra_time_charge >= 0),
  booking_deposit_percent numeric(5,2) not null check (booking_deposit_percent between 0 and 100),
  damage_deposit_required numeric(10,2) not null check (damage_deposit_required >= 0),
  status text not null default 'draft' check (status in ('draft','awaiting_deposit','confirmed','completed','cancelled')),
  notes text not null default '',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (event_end > event_start),
  check (access_start <= event_start),
  check (vacate_end >= event_end)
);

create table if not exists public.wesley_booking_services (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.wesley_bookings(id) on delete cascade,
  service_id text not null references public.wesley_services(id),
  quantity numeric(10,2) not null default 1 check (quantity > 0),
  unit_price numeric(10,2) not null default 0 check (unit_price >= 0),
  created_at timestamptz not null default now(),
  unique (booking_id, service_id)
);

create table if not exists public.wesley_payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.wesley_bookings(id) on delete cascade,
  payment_type text not null check (payment_type in ('booking_deposit','rental_balance','damage_deposit','damage_refund','other')),
  amount numeric(10,2) not null check (amount > 0),
  payment_method text not null default '',
  payment_reference text not null default '',
  payment_date timestamptz not null default now(),
  notes text not null default '',
  recorded_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.wesley_contract_records (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.wesley_bookings(id) on delete cascade,
  storage_path text not null,
  generated_at timestamptz not null default now(),
  generated_by uuid default auth.uid()
);

create index if not exists wesley_bookings_event_date_idx on public.wesley_bookings(event_date);
create index if not exists wesley_bookings_hall_time_idx on public.wesley_bookings(hall_space_id, access_start, vacate_end);
create index if not exists wesley_bookings_status_idx on public.wesley_bookings(status);
create index if not exists wesley_payments_booking_idx on public.wesley_payments(booking_id);

create or replace function wesley_private.set_updated_at()
returns trigger language plpgsql security invoker set search_path = pg_catalog, public as $$
begin new.updated_at = now(); return new; end;
$$;

create or replace function wesley_private.prepare_booking()
returns trigger language plpgsql security invoker set search_path = pg_catalog, public as $$
declare r record;
begin
  select booking_deposit_percent, damage_deposit_amount into r from public.wesley_rental_settings where id = 1;
  if new.reference_number is null or btrim(new.reference_number) = '' then
    new.reference_number := 'WH-' || extract(year from new.event_date)::int || '-' || lpad(nextval('public.wesley_booking_ref_seq')::text, 6, '0');
  end if;
  if new.booking_deposit_percent is null then new.booking_deposit_percent := coalesce(r.booking_deposit_percent, 50); end if;
  if new.damage_deposit_required is null then new.damage_deposit_required := coalesce(r.damage_deposit_amount, 500); end if;
  return new;
end;
$$;

create or replace function wesley_private.prevent_booking_overlap()
returns trigger language plpgsql security invoker set search_path = pg_catalog, public as $$
declare requested_group text;
begin
  if new.status = 'cancelled' then return new; end if;
  select conflict_group into requested_group from public.wesley_hall_spaces where id = new.hall_space_id;
  if exists (
    select 1 from public.wesley_bookings b
    join public.wesley_hall_spaces hs on hs.id = b.hall_space_id
    where b.id <> new.id and b.status <> 'cancelled'
      and hs.conflict_group = requested_group
      and new.access_start < b.vacate_end and new.vacate_end > b.access_start
  ) then
    raise exception 'Wesley Hall booking conflict: hall is already reserved during setup/event/cleanup time.';
  end if;
  return new;
end;
$$;

create or replace function wesley_private.refresh_booking_status(p_booking_id uuid)
returns void language plpgsql security invoker set search_path = pg_catalog, public as $$
declare current_status text; required_deposit numeric(12,2); paid_deposit numeric(12,2);
begin
  select b.status,
    (b.hall_charge + b.extra_time_charge + coalesce(sum(bs.quantity * bs.unit_price),0)) * b.booking_deposit_percent / 100
  into current_status, required_deposit
  from public.wesley_bookings b left join public.wesley_booking_services bs on bs.booking_id = b.id
  where b.id = p_booking_id group by b.id;
  if not found or current_status in ('cancelled','completed') then return; end if;
  select coalesce(sum(amount),0) into paid_deposit from public.wesley_payments
  where booking_id = p_booking_id and payment_type = 'booking_deposit';
  update public.wesley_bookings
    set status = case when paid_deposit >= required_deposit then 'confirmed' else 'awaiting_deposit' end
  where id = p_booking_id;
end;
$$;

create or replace function wesley_private.payment_refresh_trigger()
returns trigger language plpgsql security invoker set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then perform wesley_private.refresh_booking_status(old.booking_id); return old; end if;
  if tg_op = 'UPDATE' and new.booking_id is distinct from old.booking_id then perform wesley_private.refresh_booking_status(old.booking_id); end if;
  perform wesley_private.refresh_booking_status(new.booking_id); return new;
end;
$$;

create or replace function public.wesley_has_booking_conflict(
  p_hall_space_id text, p_access_start timestamp, p_vacate_end timestamp, p_exclude_booking_id uuid default null
)
returns boolean language sql stable security invoker set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.wesley_bookings b
    join public.wesley_hall_spaces existing_space on existing_space.id = b.hall_space_id
    join public.wesley_hall_spaces requested_space on requested_space.id = p_hall_space_id
    where b.status <> 'cancelled'
      and (p_exclude_booking_id is null or b.id <> p_exclude_booking_id)
      and existing_space.conflict_group = requested_space.conflict_group
      and p_access_start < b.vacate_end and p_vacate_end > b.access_start
  );
$$;

-- updated_at triggers
create or replace trigger wesley_org_updated before update on public.wesley_organization_settings for each row execute function wesley_private.set_updated_at();
create or replace trigger wesley_rental_updated before update on public.wesley_rental_settings for each row execute function wesley_private.set_updated_at();
create or replace trigger wesley_spaces_updated before update on public.wesley_hall_spaces for each row execute function wesley_private.set_updated_at();
create or replace trigger wesley_services_updated before update on public.wesley_services for each row execute function wesley_private.set_updated_at();
create or replace trigger wesley_terms_updated before update on public.wesley_rental_terms for each row execute function wesley_private.set_updated_at();
create or replace trigger wesley_bookings_updated before update on public.wesley_bookings for each row execute function wesley_private.set_updated_at();
create or replace trigger wesley_prepare_booking before insert on public.wesley_bookings for each row execute function wesley_private.prepare_booking();
create or replace trigger wesley_prevent_overlap before insert or update of hall_space_id, access_start, vacate_end, status on public.wesley_bookings for each row execute function wesley_private.prevent_booking_overlap();
create or replace trigger wesley_payment_status after insert or update or delete on public.wesley_payments for each row execute function wesley_private.payment_refresh_trigger();
create or replace trigger wesley_service_status after insert or update or delete on public.wesley_booking_services for each row execute function wesley_private.payment_refresh_trigger();

-- Initial values from the current Wesley Hall agreement.
insert into public.wesley_organization_settings (id) values (1) on conflict (id) do nothing;
insert into public.wesley_rental_settings (id) values (1) on conflict (id) do nothing;
insert into public.wesley_hall_spaces (id,name,conflict_group,base_rate) values
 ('full-hall','Full Hall','main-hall',0),('half-hall','Half Hall','main-hall',0)
on conflict (id) do nothing;
insert into public.wesley_services (id,name,pricing_type,price,display_order) values
 ('kitchen-cooking','Kitchen - Cooking','flat',500,1),
 ('warming-only','Warming of Food Only','flat',150,2),
 ('projector','Projector','flat',150,3),
 ('waiter','Waiter / Waitress','hourly',14,4)
on conflict (id) do nothing;
insert into public.wesley_rental_terms (id,term_text,display_order) values
 ('paper-01','By signing this agreement and making the required 50% non-refundable booking deposit, the booking date is guaranteed. No reimbursement of the booking deposit shall be made if the client cancels.',1),
 ('paper-02','A refundable damage deposit of $500.00 is required and will be refunded if no damage is caused.',2),
 ('paper-03','The balance owing must be paid before the event date.',3),
 ('paper-04','The building is non-smoking. No smoking is permitted inside the hall, kitchen, or washrooms.',4),
 ('paper-05','Decorations must not be attached using nails, staples, tacks, or tape.',5),
 ('paper-06','The venue shall not accept responsibility for any property damage or injury.',6),
 ('paper-07','If a false alarm call occurs, the client will reimburse the venue.',7),
 ('paper-08','Security is required for events where alcohol is served.',8),
 ('paper-09','No illegal activities are permitted.',9)
on conflict (id) do nothing;

-- Data API grants and RLS.
grant usage on schema public to authenticated;
grant select on public.wesley_staff_users to authenticated;
grant select,insert,update,delete on public.wesley_organization_settings,public.wesley_rental_settings,public.wesley_hall_spaces,public.wesley_services,public.wesley_rental_terms,public.wesley_bookings,public.wesley_booking_services,public.wesley_payments,public.wesley_contract_records to authenticated;
grant usage,select on sequence public.wesley_booking_ref_seq to authenticated;
grant execute on function public.wesley_has_booking_conflict(text,timestamp,timestamp,uuid) to authenticated;
grant usage on schema wesley_private to authenticated;
grant execute on function wesley_private.refresh_booking_status(uuid) to authenticated;

alter table public.wesley_staff_users enable row level security;
alter table public.wesley_organization_settings enable row level security;
alter table public.wesley_rental_settings enable row level security;
alter table public.wesley_hall_spaces enable row level security;
alter table public.wesley_services enable row level security;
alter table public.wesley_rental_terms enable row level security;
alter table public.wesley_bookings enable row level security;
alter table public.wesley_booking_services enable row level security;
alter table public.wesley_payments enable row level security;
alter table public.wesley_contract_records enable row level security;

create policy wesley_staff_self_select on public.wesley_staff_users for select to authenticated using (user_id = (select auth.uid()));

-- All active Wesley Hall staff can read settings; only manager/admin can change settings.
do $$ declare t text; begin
  foreach t in array array['wesley_organization_settings','wesley_rental_settings','wesley_hall_spaces','wesley_services','wesley_rental_terms'] loop
    execute format('create policy wesley_read on public.%I for select to authenticated using (exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active))',t);
    execute format('create policy wesley_manager_insert on public.%I for insert to authenticated with check (exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active and s.role in (''admin'',''manager'')))',t);
    execute format('create policy wesley_manager_update on public.%I for update to authenticated using (exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active and s.role in (''admin'',''manager''))) with check (exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active and s.role in (''admin'',''manager'')))',t);
  end loop;
end $$;

-- Active Wesley Hall staff can work with operational booking/payment records.
do $$ declare t text; begin
  foreach t in array array['wesley_bookings','wesley_booking_services','wesley_payments','wesley_contract_records'] loop
    execute format('create policy wesley_ops_select on public.%I for select to authenticated using (exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active))',t);
    execute format('create policy wesley_ops_insert on public.%I for insert to authenticated with check (exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active))',t);
    execute format('create policy wesley_ops_update on public.%I for update to authenticated using (exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active)) with check (exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active))',t);
  end loop;
end $$;

-- Private bucket for manager signatures and generated contracts.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('wesley-hall-private','wesley-hall-private',false,10485760,array['image/png','image/jpeg','application/pdf'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy wesley_storage_read on storage.objects for select to authenticated using (
  bucket_id='wesley-hall-private' and exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active)
);
create policy wesley_storage_insert on storage.objects for insert to authenticated with check (
  bucket_id='wesley-hall-private' and (
    (name like 'manager-signatures/%' and exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active and s.role in ('admin','manager')))
    or (name like 'contracts/%' and exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active))
  )
);
create policy wesley_storage_update on storage.objects for update to authenticated using (
  bucket_id='wesley-hall-private' and exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active and s.role in ('admin','manager'))
) with check (
  bucket_id='wesley-hall-private' and exists (select 1 from public.wesley_staff_users s where s.user_id=(select auth.uid()) and s.active and s.role in ('admin','manager'))
);
