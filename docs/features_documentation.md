# GhanaClass School Management - Features Documentation

**Document date:** 2026-02-05  
**Purpose:** Current reference for the user-facing features and supported portal structure in this codebase.

---

## Table of Contents

1. System Overview
2. Authentication and Access Control
3. Supported Portals
4. Core Admin and Staff Modules
5. Teacher Portal
6. Finance and Accountant Access
7. Shop and POS
8. Exams, Reports, and PDFs
9. Messaging and Guardian Data
10. Settings, Offline Use, and Reliability

---

## 1) System Overview

GhanaClass School Management is a Windows Flutter desktop application organized around role-based access. The app uses `go_router` route guards, role-based side navigation, PDF generation for key school documents, and local-first data handling with optional server-backed workflows.

---

## 2) Authentication and Access Control

### Login

- **Route:** `/login`
- Staff users must select the portal that matches their assigned role.
- Wrong-role, wrong-password, offline, and timeout cases return explicit error messages.

### Registration

- **Route:** `/register`
- Used for initial institutional onboarding.

### Supported access model

The application currently supports these portal roles:

- Admin
- Director
- Headmaster
- Headmistress
- Teacher
- Accountant
- Shop

Retired portals such as Parent, Secretary, Security, Library, Infirmary, Chef, ICT Lab, Science Lab, and Deputy Head are no longer routable in the application.

---

## 3) Supported Portals

### Admin

Primary landing and management experience for whole-school administration.

Typical access includes:

- Dashboard
- Students
- Staff
- Classes and subjects
- Teacher assignments
- Attendance
- Finance
- Communications
- Inbox
- Profile and messages
- ID cards
- Alarms
- Settings

### Director

- **Routes:** `/director`, `/director/:sectionId`
- Used for director-level oversight and section-driven administration.

### Headmaster and Headmistress

- **Route:** `/headmaster`
- Used for leadership workflows routed through the headship portal.

### Teacher

- **Routes:** `/teacher`, `/teacher/profile`, `/teacher/messages`, `/teacher/classes`, `/teacher/lesson-notes`, `/teacher/reports`
- Includes teaching, student-facing, attendance, and report workflows.

### Accountant

- **Routes:** `/accountant`, `/accountant/profile`, `/accountant/messages`
- Works alongside the finance module for accounting workflows.

### Shop

- **Routes:** `/pos`, `/inventory`, `/shop/profile`, `/shop/messages`, `/shop/suppliers`, `/shop/wallet`, `/shop/reports`
- Handles point-of-sale and stock operations.

---

## 4) Core Admin and Staff Modules

### Dashboard

- **Route:** `/dashboard`
- Entry point for admin and fallback home for supported staff roles.

### Inbox

- **Route:** `/inbox`
- Shared staff inbox for notifications and messages.

### Profile and Messages

- **Routes:** `/profile`, `/messages`
- Shared account pages for staff-facing profile and messaging access.

### Students

- **Routes:** `/students`, `/students/admission`, `/students/:id`
- Includes admission, profile management, profile PDF printing, ID card PDF generation, and terminal report access.

### Staff

- **Routes:** `/staff`, `/staff/admission`, `/staff/:id`, `/staff/repair`
- Includes staff registry, admission, and profile management.

### Academics

- **Routes:** `/classes`, `/classes/promotion`, `/subjects`, `/teacher-assignments`
- Covers academic structure and teacher assignment workflows.

### Attendance

- **Route:** `/attendance`
- Central attendance management.

### Communications

- **Route:** `/communications`
- School-wide communication and notification workflows.

### ID Cards

- **Route:** `/id-cards`
- Generates printable card outputs.

### Alarms

- **Route:** `/alarms`
- Admin-only siren and alarm tools.

---

## 5) Teacher Portal

Teacher workflows include:

- Class and student access
- Lesson notes
- Attendance support
- Teacher reports
- Teacher profile and messages

Teacher report workflows also expose terminal report style selection for generated report PDFs.

---

## 6) Finance and Accountant Access

### Finance core

- **Routes:** `/finance/fees`, `/finance/payments`, `/finance/payroll`, `/finance/expenses`, `/finance/analytics`
- Used for fees, payments, payroll, expense tracking, and dashboards.

### Accountant portal

- **Routes:** `/accountant`, `/accountant/profile`, `/accountant/messages`
- Related supporting pages may include placeholders for future accounting modules such as billing, arrears, reconciliation, or assets.

---

## 7) Shop and POS

Shop workflows include:

- Point of sale via `/pos`
- Stock management via `/inventory`
- Suppliers via `/shop/suppliers`
- Wallet and reports via `/shop/wallet` and `/shop/reports`
- Role-specific profile and messages pages

---

## 8) Exams, Reports, and PDFs

### Exams tools

- **Routes:** `/exams/bank`, `/exams/generate`
- Protected by role-based access guards.

### PDF outputs

Implemented PDF workflows include:

- Student profile PDF
- Student ID card PDF
- Terminal report PDF

### Report card styling

Terminal reports support:

- Multiple templates
- Multiple accent colors
- Persistence of the last selected style

---

## 9) Messaging and Guardian Data

The app still keeps guardian and parent account data for operational workflows such as:

- Student-to-guardian linkage
- Teacher-to-guardian communication where an account exists
- Parent-related records in the local data model

What has changed:

- There is no supported Parent portal login path.
- Parent routes are retired.
- Guardian data remains available as school data, not as a standalone user portal.

---

## 10) Settings, Offline Use, and Reliability

### Settings

- **Route:** `/settings`
- Application and school configuration access.

### Offline and sync notes

The codebase includes local-first behavior and sync-related infrastructure. Users may continue to work in local mode depending on deployment, while some environments may enable server-backed workflows.

### Reliability notes

Current runtime protections include:

- Login timeout handling
- Offline-friendly error messages
- Safe redirects away from retired portal routes

---

## Quick Route Summary

Authentication:

- `/register`
- `/login`

Core shell:

- `/dashboard`
- `/students`
- `/staff`
- `/classes`
- `/subjects`
- `/teacher-assignments`
- `/attendance`
- `/finance/*`
- `/communications`
- `/inbox`
- `/profile`
- `/messages`
- `/id-cards`
- `/alarms`
- `/settings`

Supported portals:

- `/director`
- `/headmaster`
- `/teacher/*`
- `/accountant/*`
- `/pos`
- `/inventory`
- `/shop/*`
