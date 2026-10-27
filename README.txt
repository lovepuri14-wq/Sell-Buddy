SELLBUDDY - Windows 11 starter project
======================================

WHAT THIS PROJECT INCLUDES
- Responsive customer shopping website
- Seller admin login/dashboard
- Product create/update/hide and stock management
- Checkout with Cash on Delivery
- SQLite database saved on the laptop
- Flutter Android customer app that uses the same backend API

IMPORTANT LIMITATIONS
- This is a starter MVP, not yet a public-production marketplace.
- Orders work only while the backend is running and reachable.
- Online payments, courier integrations, OTP/login, refunds, tax invoices, image uploads and production hosting are not configured.
- Before publishing publicly: set strong secret/admin credentials, use HTTPS, add rate limiting/CSRF protections, backups, privacy policy and proper deployment configuration.
- The admin login defaults are for local testing only. Do not expose them publicly.
- The Flutter app's default API URL is for Android Emulator (10.0.2.2). A physical phone or public APK needs the correct backend URL.

A. RUN WEBSITE + BACKEND (Windows)
1. Install Python 3.11 or 3.12 from https://www.python.org/downloads/windows/
   During installation, tick "Add python.exe to PATH".
2. Open the extracted SellBuddy folder.
3. Double-click START_BACKEND.bat.
4. Wait until it says the server is running.
5. Open http://127.0.0.1:5000 for the customer shop.
6. Open http://127.0.0.1:5000/admin/login for the admin panel.
   Local test login: admin
   Local test password: ChangeMe123!
7. Keep the backend window open while using the website/app.
8. SQLite database will be created at backend/sellbuddy.db.

B. RUN THE ANDROID APP
1. Install Flutter and Android Studio (Android SDK) if not already installed.
2. Open a NEW PowerShell in the extracted SellBuddy folder.
3. Run:
   cd mobile
   flutter pub get
   flutter run
4. Start an Android emulator in Android Studio first, or connect an Android phone with USB debugging.
5. The default URL http://10.0.2.2:5000 is for Android Emulator.
   For a physical phone on the same Wi-Fi, edit the backend URL at build time:
   flutter run --dart-define=API_BASE_URL=http://YOUR_LAPTOP_LAN_IP:5000
   Find laptop IP using `ipconfig` (IPv4 Address). Keep laptop and phone on the same Wi-Fi.
   Windows Firewall may ask whether Python can accept local network connections.

C. BUILD AN APK
1. Make sure the backend URL is reachable from the device that will use the app.
2. In PowerShell:
   cd mobile
   flutter pub get
   flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-DEPLOYED-BACKEND-DOMAIN
3. APK location:
   mobile\build\app\outputs\flutter-apk\app-release.apk
   Replace the example URL with your real HTTPS backend domain before distributing.
   A public HTTPS backend must be deployed first. Do not use the laptop's local URL for customers outside your Wi-Fi.

D. CHANGE ADMIN LOGIN BEFORE PUBLIC HOSTING
Set environment variables before starting the backend:
  set SELLBUDDY_ADMIN_USER=your_username
  set SELLBUDDY_ADMIN_PASSWORD=your_strong_password
  set SELLBUDDY_SECRET=replace_with_a_long_random_secret
Then run:
  python app.py
For local testing, the included START_BACKEND.bat uses the demo credentials.

E. IMPORTANT BUSINESS NOTES
- Do not store card details yourself.
- Online payment integration should use a reputable payment gateway and server-side verification.
- Shipping/courier booking and live tracking require a provider account and credentials.
- Add clear return/refund policy, shipping charges, privacy policy and contact details before accepting real customers.
