# Wesley Hall Product Roadmap

This checklist tracks the features that will turn Wesley Hall into a complete hall-management system.

## Phase 1 - Core Operations

- [x] Booking File / Timeline
  - Show application, contract, signatures, payments, status changes, documents, and edits in one booking history.
  - Keep all uploaded documents attached to the booking.
- [x] Temporary Hold / Pending Date
  - Allow a date to be held temporarily before deposit payment.
  - Support configurable 24 / 48 / 72-hour hold expiry.
  - Show holds distinctly on the Hall Planner.
  - Show exact hold expiry in Bookings.
  - Convert a hold to Awaiting Deposit.
  - Extend or release a hold.
  - Expired holds stop blocking the hall automatically.
- [x] Payment Receipts
  - Generate printable receipts for booking deposit, rental balance, damage deposit, and refunds.
  - Use booking reference + client name in filenames.
- [x] Financial Reports
  - Monthly bookings and rental income.
  - Outstanding balances.
  - Damage deposits held/refunded.
  - Church Use vs External Rental.
  - Services used.
  - CSV export can be added as a report enhancement.

## Phase 2 - Scheduling & Productivity

- [x] Recurring Church Activities
  - Repeat weekly or monthly.
  - Church Use only; no payment required.
  - Every occurrence passes conflict checking before the series is saved.
  - Link recurring occurrences into a managed series.
  - Show series number (for example 3 of 12).
  - Update non-scheduling details on future occurrences.
  - Cancel one occurrence, this-and-future, or the whole remaining series.
  - Selected custom dates can be added as a later enhancement.
- [x] Duplicate / Copy Reservation
  - Copy an existing rental or church-use reservation into a fresh reservation.
  - Suggest the next matching weekday and allow date/time/hall changes before saving.
  - Recheck hall conflicts before creating the copy.
  - Use current hall/service rates and current deposit rules.
  - Assign a new booking reference automatically.
  - Do not copy payments, signatures, documents, holds, inspections, or recurring-series links.
- [x] Booking Completion / Damage Inspection
  - Record no damage / damage found.
  - Add inspection notes and photos.
  - Record damage deduction and refund.
  - Mark booking Completed.
  - Allow tablet camera capture or photo upload for inspection evidence.
  - Show inspection activity in the booking timeline.

## Phase 3 - Communication & Governance

- [ ] Communication Centre
  - Send confirmation.
  - Send contract.
  - Send balance reminder.
  - Send event reminder.
- [x] Staff Roles & Permissions
  - Administrator: full access including staff management.
  - Manager: bookings, finance, settings, documents and inspections.
  - Booking Officer: bookings, contracts, documents, payments and inspections.
  - Finance: financial reports, payments and receipts without booking/settings changes.
  - Viewer: read-only planner and booking information.
  - Enforce permissions in both Flutter navigation and Supabase RLS.
  - Admin can create staff users, change roles/status and reset passwords securely through a server-side Edge Function.
- [x] Audit Trail
  - Record booking creation, edits, status changes, signatures, payments, and inspections.
  - Extend to settings changes as governance work is completed.

## Phase 4 - Document & Tablet Workflow

- [x] Print Blank Application with current live rates.
- [x] Attach a completed paper application to a booking.
- [x] Scan / upload a paper application and review extracted information before planner entry.
- [ ] Tablet Reception Mode
  - New application.
  - Camera scan or manual entry.
  - Review.
  - Client signs on screen.
  - Receive deposit.
  - Generate/print/email contract.
- [x] Document Centre
  - Per-booking electronic folder.
  - Original/paper applications.
  - Signed contracts and other PDFs/images.
  - Receipts and correspondence.
  - Damage/inspection reports.
  - Role-controlled upload/delete.
  - View images and print/save PDFs.

## Implementation Order

1. Booking File / Timeline + Audit Trail - COMPLETE
2. Payment Receipts + Financial Reports - COMPLETE
3. Recurring Church Activities + Series Management - COMPLETE
4. Temporary Hold / Pending Date - COMPLETE
5. Booking Completion / Damage Inspection - COMPLETE
6. Staff Roles & Permissions - COMPLETE
7. Document Centre - COMPLETE
8. Duplicate / Copy Reservation - COMPLETE
9. Communication Centre - NEXT
10. Tablet Reception Mode
11. Go-live cleanup / backup tools
