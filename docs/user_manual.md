# GhanaClass School Management - User Manual (Windows)

**Document date:** 2026-02-05  
**Audience:** School staff and administrators using the GhanaClass desktop app on Windows.

---

## 1) Introduction

GhanaClass School Management is a desktop application for school operations. Access is controlled by role, so each user logs in through the portal assigned to that staff account.

Supported portals in the current application build:

- Administrator
- Director
- Headmaster or Headmistress
- Teacher
- Accountant
- Shop

Parent and other legacy staff portals are no longer available as login destinations.

---

## 2) Logging In

1. Open the app.
2. Enter your email address.
3. Enter your password.
4. Select the portal that matches your assigned role.
5. Click **Login**.

You may see these messages:

- Invalid email or password
- You do not have access to this portal
- Offline or connection timeout messages

If login fails, confirm that you selected the correct role before retrying.

---

## 3) Common Navigation

Most supported roles share these patterns:

- A left sidebar for the modules they can access
- An Inbox for notifications and messages
- Profile pages for account information
- Messages pages for role-based communication

Admin users see the broadest navigation. Other supported roles are redirected to their own portal home.

---

## 4) Portal Guide

### Administrator

Typical access includes:

- Dashboard
- Students
- Staff
- Classes and subjects
- Teacher assignments
- Attendance
- Finance
- Communication
- Inbox
- Profile and messages
- ID cards
- Alarms
- Settings

### Director

Director users enter through the director portal and use section-based leadership tools.

### Headmaster or Headmistress

Headship users access leadership workflows through the headmaster portal.

### Teacher

Typical teacher access includes:

- Classes
- Students
- Lesson notes
- Attendance support
- Reports
- Profile
- Messages

Some deployments also expose exam tools such as the question bank and exam generator.

### Accountant

Typical accountant access includes:

- Accountant portal home
- Profile
- Messages
- Finance workflows for fees, payments, payroll, expenses, and analytics

Some accounting pages may still show placeholders for future modules.

### Shop

Typical shop access includes:

- POS
- Inventory
- Suppliers
- Wallet
- Reports
- Profile
- Messages

---

## 5) Reports and PDFs

The application can generate PDF outputs for key school records, including:

- Student profile documents
- Student ID cards
- Terminal reports

Terminal reports support multiple templates and accent colors.

---

## 6) Guardian and Parent Information

Guardian and parent account data can still exist in the system for operational purposes such as student linkage and teacher-to-guardian communication.

What changed:

- There is no Parent portal login.
- Parent pages are not part of the supported navigation.
- Guardian records remain available as school data.

---

## 7) Offline Use and Reliability

Depending on deployment, the app may run in local-first mode or with server-backed features enabled.

Built-in protections include:

- Clear login failure messages
- Timeout handling for slow login operations
- Safe redirects away from retired portal routes

---

## 8) Troubleshooting

### I cannot log in

Check these first:

- Your email address
- Your password
- Your selected role
- Whether the device is offline

### I do not see a portal I used before

That portal may have been retired from the current build. Contact your administrator if you are unsure which supported role applies to your account.

### I need parent access

Parent and guardian records may still exist in the system, but the dedicated Parent portal is not enabled in this build.
