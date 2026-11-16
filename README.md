# EasyLoad Shop Manager — Android Flutter Migration

This Android project is being migrated from the supplied Windows Tkinter `MOBILE LOAD` source. It uses local SQLite storage and includes the supplied EasyLoad logo and provider logo assets.

## Included Android sections
- Dashboard
- Sales and Purchase
- Stock Management / Products
- EasyPaisa, JazzCash and EasyLoad service ledgers
- Customers and supplier purchase summary
- Payments / Receipts
- Damaged / Lost Stock adjustments
- EasyLoad Hisab / E Zero with Opening + 2 Day Load, Total Balance - Sale, and RSO Remaining - Transfer - RSO Katta formulas
- Monthly estimated Profit & Loss
- PDF report
- Backup and Restore
- QR / Barcode camera scanner
- Settings and subscription screen

## Subscription configuration
- Free trial: 7 days
- Monthly: PKR 500
- Yearly: PKR 5,000
- Manual payment: JazzCash / Easypaisa
- Payment account title and number are configured in Settings.

**Important subscription limitation:** the current implementation stores payment requests and activation locally on the same device. It does not yet provide server-side accounts, email verification, remote approval, or automatic payment verification. It is a test/manual workflow, not a tamper-resistant commercial subscription service. Clearing app data/reinstalling may reset local trial state. A production subscription needs a secure backend and server-side validation.

## Android app icon
The original `easyload_logo.png` from the supplied Windows project is included at `assets/easyload_logo.png`. GitHub Actions runs `dart run flutter_launcher_icons` to generate the Android launcher icon and sets the app label to **EasyLoad Shop Manager**.

## Build APK with GitHub Actions
1. Upload this project folder to a GitHub repository.
2. Open **Actions**.
3. Run **Build Android APK** (or push to `main` / `master`).
4. Download the `EasyLoad-Shop-Manager-APK` artifact after the workflow succeeds.

## Migration notes / not yet production-complete
- The supplied ZIP is a Windows Python/Tkinter app; it is not an Android source project. The Flutter pages are reimplementations, not a direct binary conversion.
- No `records.db` database was present in the supplied ZIP, so existing Windows customer/stock records cannot be imported from this archive.
- Full parity still requires device testing and completing edit/delete coverage, camera/USB scanner integration directly in Purchase and Sale forms, accurate item-level cost-of-goods profit calculations, and verification of all E Zero date-wise carry-forward and grid totals.
- The Profit & Loss page is clearly marked as an estimate until item-level cost tracking is completed.
- The APK has not been compiled in this environment because Flutter/Dart SDKs are not installed here. Use the included GitHub Actions workflow to build and share any error log for correction.

## First login
- Username: `admin`
- Password/PIN: `1234`

Change these in Settings after login.
