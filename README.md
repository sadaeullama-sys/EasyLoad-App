# EasyLoad Shop Manager — Android Flutter project

This Flutter Android project is a migration baseline for the EasyLoad Shop Manager.

## Subscription settings included

- Free trial: 7 days from the first app database initialization.
- Monthly plan: PKR 500.
- Yearly plan: PKR 5,000.
- Payment method: manual JazzCash or Easypaisa.
- Payment request fields: account email, payer name, payer mobile number, and transaction/reference ID.
- Subscription states: trial, pending payment request, active subscription, and expired trial.
- Admin can review/approve the latest pending request using the app's Admin PIN.
- Subscription expiry is saved locally and checked when the app starts.

## Configure the receiving payment accounts

Open **Settings → Manual Subscription Payment Accounts** and enter:
- JazzCash account title and number
- Easypaisa account title and number

Save settings. These details appear on the Subscription screen.

## Important deployment limitations

This archive adds a local/offline subscription workflow only. It does **not** yet include verified email registration, a cloud backend, remote payment-request delivery, automatic bank/JazzCash/Easypaisa transaction verification, or server-side subscription enforcement. The payment request is stored on the current device; local Admin approval is intended for development/testing and is not a secure production subscription service. For a production multi-customer subscription service, a backend with authenticated accounts and server-side payment verification/activation is required.

The 7-day trial timestamp is stored in the local SQLite database. Clearing app data or reinstalling may reset a local-only trial; server-side trial enforcement is not included.

## Existing app modules

Local SQLite login, dashboard, stock, purchase, sale, mobile services, E Zero/RSO formulas, customers, payments, expenses, PDF report, local backup, and settings.

The E Zero formulas remain:
- Total Balance = Opening Balance + 2 Day Load
- Remaining = Total Balance - Sale
- Remaining Ledger = RSO Total Remaining - Today Transfer - RSO Katta

## Build

Push this folder to GitHub and use the included `.github/workflows/build-apk.yml` workflow, or run:

```bash
flutter pub get
flutter build apk --release
```

The build requires Flutter and the Android SDK. This environment did not compile the APK, so the source changes still need a GitHub Actions or local Flutter build/test.


### Network logos in their matching sections
The Services screen now shows each provider logo beside its matching provider name as selectable tiles (Jazz, Zong, Telenor, Ufone, SCO, ONIC, One Load, and other service entries). The E Zero / RSO company selector also displays the matching logo next to the provider name and shows the selected provider logo above the ledger fields.
