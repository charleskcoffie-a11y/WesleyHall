# Wesley Hall

Wesley Hall is the GMCT desktop application for hall booking, hall planning, payments, and printable rental agreements.

## Version 0.3

Current workflow:

- Dashboard with today's events, weekly events, outstanding balances, and deposit alerts
- Hall Planner with setup/event/cleanup occupancy blocking
- New Booking with Full Hall / Half Hall, services, charges, 50% booking deposit, and damage deposit
- Booking Details and Payments
  - Booking Deposit
  - Rental Balance
  - Damage Deposit
  - Damage Deposit Refund
  - Payment method, reference/receipt number, and notes
  - Automatic booking confirmation when the required booking deposit has been received
- Printable Wesley Hall Agreement
- Manager name/title and uploaded signature in Settings
- Editable setup/cleanup rules, rates, services, and rental conditions
- Supabase Auth + RLS
- Private Supabase Storage for manager signatures and generated contracts

## Supabase target

The application is intended to use the shared **GMCT Management System** Supabase project.

To avoid collisions with other GMCT modules, all Wesley Hall database tables use a `wesley_` prefix:

- `wesley_staff_users`
- `wesley_organization_settings`
- `wesley_rental_settings`
- `wesley_hall_spaces`
- `wesley_services`
- `wesley_rental_terms`
- `wesley_bookings`
- `wesley_booking_services`
- `wesley_payments`
- `wesley_contract_records`

The initial schema is in:

`supabase/migrations/001_wesley_hall_initial.sql`

The migration also creates the private Storage bucket `wesley-hall-private`, hall-conflict protection, booking reference generation, role-based RLS, and automatic confirmation after the required booking deposit is received.

### Staff access

Wesley Hall uses the same Supabase Auth user pool as the GMCT Management System. A signed-in user must also have a row in `wesley_staff_users`.

Roles:

- `admin`
- `manager`
- `booking_officer`

Managers/admins can modify hall settings, rates, terms, and the manager signature. Active Wesley Hall staff can work with bookings and payments.

Example first-admin bootstrap after that user's Supabase Auth account exists:

```sql
insert into public.wesley_staff_users (user_id, role)
select id, 'admin'
from auth.users
where email = 'YOUR-ADMIN-EMAIL'
on conflict (user_id) do update
set role = excluded.role, active = true;
```

## Running on Windows

The repository intentionally does not contain a Supabase secret key. The Flutter desktop client uses only the project URL and Supabase **publishable key** supplied through `--dart-define`.

First create the Windows runner if it is not already present:

```powershell
flutter create --platforms=windows .
flutter pub get
```

Run connected to Supabase:

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL="YOUR_PROJECT_URL" `
  --dart-define=SUPABASE_PUBLISHABLE_KEY="YOUR_PUBLISHABLE_KEY"
```

If the two defines are omitted, Wesley Hall opens in Demo Mode.

## GitHub

Repository: `charleskcoffie-a11y/WesleyHall`

Do not commit service-role keys, database passwords, or other Supabase secrets. The app should use a publishable client key plus RLS.
