# Wesley Hall Product Roadmap

This checklist tracks the features that will turn Wesley Hall into a complete hall-management system.

## Phase 1 - Core Operations

- [x] Booking File / Timeline
  - Show application, contract, signatures, payments, status changes, documents, and edits in one booking history.
  - Keep all uploaded documents attached to the booking.
- [ ] Temporary Hold / Pending Date
  - Allow a date to be held temporarily before deposit payment.
  - Support configurable hold expiry (for example 24 or 48 hours).
  - Show holds distinctly on the Hall Planner.
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
  - Selected custom dates can be added as a later enhancement.
- [ ] Duplicate / Copy Reservation
  - Copy an existing booking into a new draft with a new date/reference.
- [ ] Booking Completion / Damage Inspection
  - Record no damage / damage found.
  - Add inspection notes and photos.
  - Record damage deduction and refund.
  - Mark booking Completed.

## Phase 3 - Communication & Governance

- [ ] Communication Centre
  - Send confirmation.
  - Send contract.
  - Send balance reminder.
  - Send event reminder.
- [ ] Staff Roles
  - Admin.
  - Manager.
  - Booking Officer.
  - Finance / Viewer.
- [x] Audit Trail
  - Record booking creation, edits, status changes, signatures, and payments.
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
- [ ] Document Centre
  - Original application.
  - Signed contract.
  - Receipts.
  - Correspondence.
  - Damage inspection photos/reports.

## Implementation Order

1. Booking File / Timeline + Audit Trail - COMPLETE
2. Payment Receipts + Financial Reports - COMPLETE
3. Recurring Church Activities - COMPLETE
4. Temporary Hold / Pending Date - NEXT
5. Booking Completion / Damage Inspection
6. Duplicate / Copy Reservation
7. Staff Roles
8. Communication Centre
9. Tablet Reception Mode
10. Document Centre polish
