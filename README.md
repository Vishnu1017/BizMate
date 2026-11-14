<h1 align="center">
  <img src="assets/images/bizmate_logo.JPG" width="90" height="90" style="border-radius:20px"/><br/>
  BizMate
</h1>

<h3 align="center">All-in-one Business Management App for Photographers &amp; Small Businesses</h3>

<p align="center">
  <a href="https://github.com/Vishnu1017/BizMate">
    <img src="https://img.shields.io/github/stars/Vishnu1017/BizMate?style=social" alt="GitHub Stars"/>
  </a>
  <a href="https://github.com/Vishnu1017/BizMate">
    <img src="https://img.shields.io/github/forks/Vishnu1017/BizMate?style=social" alt="GitHub Forks"/>
  </a>
  <a href="https://github.com/Vishnu1017/BizMate/issues">
    <img src="https://img.shields.io/github/issues/Vishnu1017/BizMate" alt="Issues"/>
  </a>
  <a href="https://github.com/Vishnu1017/BizMate/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/Vishnu1017/BizMate" alt="License"/>
  </a>
  <img src="https://img.shields.io/badge/version-1.0.72-blue" alt="Version"/>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green" alt="Platform"/>
  <img src="https://img.shields.io/badge/Storage-Hive%20(Offline)-orange" alt="Storage"/>
  <img src="https://img.shields.io/badge/Cloud-Google%20Drive%20OAuth%202.0-4285F4?logo=googledrive" alt="Cloud"/>
</p>

---

## 🧾 About BizMate

**BizMate** is a powerful, **offline-first** Flutter application built for **photographers, freelancers, and small business owners**. It provides a complete suite of tools to manage sales, customers, products, expenses, net profit analytics, camera rental gear, bookings, dynamic UPI QR payments, and business reports — all from a single beautifully designed app.

Built with **Hive** for lightning-fast local storage, BizMate works entirely offline with no internet required for day-to-day operations. It features a premium **Business Analytics splash screen with modern Lottie animations**, **direct Google Drive cloud backup & restore** (100% direct Google Cloud OAuth 2.0 with **zero Firebase dependency**), non-restricted `driveFileScope` security compliance, automated **Workmanager background scheduling**, network constraints (Wi-Fi only vs. Any Network), customizable backup frequencies (Manual, Daily, Weekly, Monthly), local backup completion alerts, **optional End-to-End Encryption (E2EE with secret PIN)**, **dark and light themes with enhanced financial readability**, **biometric authentication**, **interactive Dynamic UPI QR codes for instant counter checkout and remote payment link sharing**, **GST-compliant PDF invoices with embedded NPCI UPI QR codes and accepted UPI app badges (Google Pay, PhonePe, Paytm, BHIM)**, an embedded **Expense Tracker with real-time Net Profit & PnL Financial Dashboard**, **universal 5-tier mobile responsiveness (<350px up to tablets)**, **zero-lag IndexedStack tab persistence**, **WhatsApp messaging**, and a dedicated **Camera Rental module** tailored for photographers.

---

## ✨ Features at a Glance

| Module | Highlights |
|---|---|
| 🔐 **Auth & Security** | Passcode, Biometrics (Face ID / Fingerprint), Auto-login, Role-based signup |
| 💫 **Splash Experience** | Centered Analytics Showcase Deck, Lottie animated 'B', glowing cyber orbitals, floating KPI cards |
| 🏠 **Dashboard & PnL** | Real-time Net Profit, Revenue vs Expenses, dual-view PnL/Revenue spline curves, edge-safe tooltips |
| 💸 **Expense Tracker** | Bottom navbar tab (Index 2), categorized expense logging, payment modes, receipt tracking, instant profit impact |
| 📲 **Dynamic UPI QR** | Interactive counter checkout dialog, customizable pre-filled amount/order note, direct UPI app launch, link sharing |
| 🛒 **Sales** | GST invoices, advance payments, payment timeline, tax calculations, contextual options menu |
| 📦 **Products** | Drag-reorder, categories, quick search, price bundles, safe initial-mount caching |
| 👥 **Customers** | WhatsApp integration with templates, direct calling, Client Release Agreement PDF |
| 📅 **Calendar** | Visual booking calendar, date-range picker, event markers |
| 🚚 **Delivery** | Status tracker with animated progress timeline |
| 💳 **Payments** | Timeline view, payment mode badges, due/paid status highlights, theme-accessible breakdown |
| 📊 **Reports** | fl_chart analytics (bar & spline curves), CSV and PDF export, revenue breakdown |
| 📁 **PDF Invoices** | GST-compliant invoices, embedded NPCI UPI QR code, crisp accepted UPI app logos (GPay, PhonePe, Paytm, BHIM), shareable via WhatsApp/Email |
| 📸 **Camera Rental** | Full rental management for photographers: gear inventory with photos, booking date pickers, customer records & rental invoices |
| 📱 **Universal Layout** | 5-Tier responsive layout engine (<350px very small, 360–390px small, 390–430px medium, 430–600px phablet, >600px tablet) |
| ⚡ **Performance** | Zero-lag `IndexedStack` tab persistence, preserved scroll offsets, Adaptive High-Hz Engine (60Hz–165Hz & LTPO), Multi-GPU hardware acceleration |
| ☁️ **Cloud Backup** | Direct Google Drive sync (OAuth 2.0, zero Firebase), `driveFileScope` security, `BizMate Backups` folder, Cloud Restore Browser, automated Workmanager scheduler (Daily, Weekly, Monthly), Wi-Fi constraint, notifications |
| 💾 **Data Protection** | On-device backups manager, recent audit logs, optional End-to-End Encryption (AES PIN), WhatsApp export, JSON file import, database health |
| 👤 **Profile** | Avatar photo picking & cropping, role badges, UPI ID configuration, passcode management |
| 🌗 **Theme** | Instant dark/light toggle on every screen with smooth transitions & high-contrast financial records |

---

## 🚀 Feature Details

### 💫 Modern Splash & Brand Identity
- **Centralized Analytics Showcase Deck** — beautifully balanced on both phone and tablet displays
- **Lottie Animated Letter 'B'** — seamless vector typography animation with smooth looping and assembly motion
- **Cybernetic Orbital Aura** — concentric orbit rings with counter-rotating neon cyan and violet arcs
- **Orbiting Kinetic Energy Sparks** — micro-particles revolving dynamically around the brand monogram
- **Financial Distribution Donut Ring** — animated 3-segment progress breakdown (Revenue 60%, Profit 25%, Expenses 15%)
- **Monthly Performance Bar Chart** — 7-month comparative analytics with dynamic spline trend curve and glowing data nodes
- **Floating Glassmorphic KPI Cards** — live preview cards for Revenue (₹2.4L), Sales (1,284), Customers (348), and Stock (96 items)

### 📁 GST PDF Invoices & Seamless UPI Payments
- **GST-Compliant Invoices** — itemized product tables, tax breakdowns, discount calculation, and customer details
- **Integrated NPCI UPI QR Code** — dynamically generated QR code encoding exact payable balance, merchant UPI ID, and payee name for instant scanning
- **Accepted UPI App Showcase** — high-resolution visual badges for **Google Pay**, **PhonePe**, **Paytm**, and **BHIM** displaying accepted payment methods without clutter or broken links
- **Fast Sharing & Export** — share invoices instantly as PDF via WhatsApp, Email, or save/print directly on the device
- **Client Release Agreement PDF** — generate standardized client release agreements with customer name and event terms

### ☁️ Google Drive Cloud Backup & Background Scheduling
- **Zero-Firebase Direct Google Cloud OAuth 2.0** (`google_sign_in`, `googleapis/drive/v3.dart`) for lightweight, secure, and privacy-first cloud synchronization
- **Non-Restricted Scoped Security (`driveFileScope`)** — strictly confined to files created by BizMate (`https://www.googleapis.com/auth/drive.file`), completely eliminating Google CASA Tier 2/3 audit requirements and preventing `403 Access Blocked` verification warnings
- **Isolated `BizMate Backups` Drive Folder** — automatically locates or creates an organized folder in the user's personal Google Drive
- **Interactive Cloud Restore Browser** — inspect all remote backups with file name, record count, exact file size, and timestamps; perform one-tap cloud restoration or remote backup deletion
- **Automated Workmanager Background Backups** — flexible scheduling with background task persistence:
  - **Only when I tap "Back up"** (Manual)
  - **Daily** (Every day background sync)
  - **Weekly** (Scheduled weekly maintenance)
  - **Monthly** (Long-term snapshot retention)
- **Network Constraint Configuration** — choose between **Backup over Wi-Fi only** (saving cellular data) or **Wi-Fi or cellular**
- **Test Auto-Sync** — on-demand diagnostic action to trigger background scheduler worker immediately and verify cloud uploads
- **Backup Completion Notifications** — automated notifications via `flutter_local_notifications` alerting users when a background backup succeeds
- **Automated Hive Box Extraction & Restoration** — complete recovery of sales, rental items, customers, products, settings, and credentials
- **In-Memory Hot Refresh** — immediate UI synchronization after restore without requiring app restarts
- **One-Tap Manual Drive Sync** — instant upload and instant restore directly from the Hero status card

### 🔐 Authentication & Security
- Email/phone login with **passcode protection**
- **Biometric authentication** (Fingerprint / Face ID) on Android & iOS
- Session management with **auto-login**
- Role-based signup: **Photographer, Sales, Manager**, and more
- Secure passcode setup, change, and removal from profile
- **Theme toggle on login & signup screen** — switch dark/light before logging in

### 🏠 Financial Dashboard & Net Profit Analytics
- **Real-Time Financial Health Metrics** — live cards calculating **Total Revenue**, **Total Expenses**, and **Net Profit** with automated profit margin indicators
- **Dual-View Segmented Analytics Toggle** — effortlessly switch between **Revenue Trend** and **Profit & Loss (PnL)** spline curve visualizations
- **fl_chart Edge-Safe Tooltip Inspection** — enhanced with `fitInsideHorizontally` and `fitInsideVertically` plus spot indicator styling, guaranteeing tooltips never clip off the screen edges
- **Adaptive Multi-Tier Metric Layout** — stacks into full-width cards on small screens, 2-column cards on standard phones, and 3-column horizontal grid on tablets
- **Integrated Operational Actions** — one-tap buttons to jump directly into **Manage Expenses** or explore **Sales Insights**
- **Home Sales Feed** — recent sales with customer info, payment status badges (All / PAID / PARTIAL / DUE), search, date filters, and quick invoice actions

### 💸 Expense Tracker (Embedded Navbar Tab)
- **Direct Bottom Navigation Access** — embedded as Tab index 2 directly between Dashboard and Customers for rapid bookkeeping
- **Granular Expense Categorization** — log expenses under Rent, Equipment, Travel, Marketing, Maintenance, Salaries, Utilities, and Miscellaneous
- **Payment Method & Receipt Tracking** — tag payment modes (UPI, Cash, Card, Bank) and store vendor remarks with timestamps
- **Instant PnL Synchronization** — any added or edited expense immediately updates the Net Profit cards and graphs across the entire app
- **Search & Category Filtering** — auto-stacking filter row adapting cleanly to mobile widths with wrapped badge tags for zero horizontal overflow

### 📲 Dynamic UPI QR Codes & Instant Checkout Dialog
- **Interactive Counter Checkout Modal (`DynamicUpiQrDialog`)** — generate on-the-fly NPCI-compliant UPI QR codes encoding merchant VPA, payee name, transaction note, order ID, and exact balance
- **Real-Time Custom Amount Editing** — adjust the payable amount directly inside the dialog without leaving the screen
- **Direct UPI App Launching** — one-tap deep-linking into installed apps (Google Pay, PhonePe, Paytm, BHIM) with automatic fallback
- **Shareable Payment Link Payload** — share pre-composed payment links containing merchant details and UPI URI via native share sheet (WhatsApp, SMS, Email)
- **One-Tap 'Mark as Paid' Confirmation** — records the payment immediately, appends to the sale timeline, and updates business revenue
- **Omnipresent Access Points**:
  - Contextual **Sale Options Menu** (`Collect via UPI QR`)
  - **PDF Invoice Preview Screen** (Top AppBar action button)
  - **Sale Detail / Edit Screen** (Prominent "Show Dynamic UPI QR" button)

### 📱 Universal 5-Tier Mobile & Multi-Device Responsiveness
- **Very Small Mobile (<350px, e.g. iPhone SE 1st gen, 320px Android)**: Tailored 0.76x scaling, 6–8px padding, single-column stacked metric cards, auto-collapsing search/date rows, and ellipsis text truncation
- **Small Mobile (350px–390px, e.g. iPhone 12/13 mini, iPhone SE 2/3)**: 0.85x proportional scaling, compact filter chips, and flexible badge wrapping
- **Medium Mobile (390px–430px, e.g. iPhone 14/15/16, Galaxy S23/S24, Pixel 7/8/9)**: 0.95x standard layout with complete avatar columns and spacious typography
- **Big Mobile / Phablet (430px–600px, e.g. iPhone Pro Max, Galaxy Ultra)**: 1.02x scale factor, generous touch targets, and expanded list tiles
- **Tablets & Desktop (>600px)**: Centered layout constraints (900px–1200px max width), multi-column grids, and full horizontal data layouts

### ⚡ Zero-Lag Tab Switching & State Persistence Engine
- **`IndexedStack` Architecture** — tabs in `NavBarPage` and `CameraRentalNavBar` remain mounted in memory, completely eliminating rebuild delays and simulator lag
- **Preserved Scroll Offsets & Input State** — scrolling through sales or typing search queries is retained when switching between tabs
- **Initial-Mount Null-Safety Guards** — safe asynchronous Hive box initialization across all views (`ProductsPage`, `CustomersPage`, `DashboardPage`) preventing null-operator race conditions

### 🛒 Sales Management
- Create and manage **GST-compliant sales/invoices**
- Add multiple products per sale with quantity and pricing
- Track **advance payments**, **balance due**, and **payment history timeline**
- Edit sales, update received amounts, change payment mode
- Mark delivery status and due dates per sale
- Contextual **Sale Options Menu** for fast status changes, sharing, and payment logs
- Full **sale detail screen** with high-contrast payment breakdown and progress ring

### 📦 Products / Items
- Add, edit, reorder, and delete products with pricing
- Drag-and-drop reordering support
- Searchable product list with category chips
- Role-aware product management

### 👥 Customers
- Customer directory with name, phone, and initials avatars
- Direct **phone call** integration
- **WhatsApp messaging** with pre-built message templates
- Send **Release Agreement PDF** directly via WhatsApp
- Delete with swipe-to-dismiss and confirmation dialog

### 📅 Calendar & Booking
- Visual **booking calendar** with event date markers
- Date range selection for bookings and rentals
- Upcoming event highlights and color-coded indicators

### 🚚 Delivery Tracker
- Track delivery status per sale
- Mark delivery as pending, in-transit, or delivered
- Visual delivery timeline with animated progress

### 💳 Payment History & Financial Insights
- Chronological **payment timeline** per sale
- Animated progress bar showing % paid
- Payment mode badges (Cash, UPI, Card, Online, Bank)
- High-contrast balance due and fully-paid visual highlights in both Dark & Light themes

### 📊 Sales Report
- Revenue analytics with **fl_chart** bar and line charts
- Filter by date range, payment status, and customer
- Export report as **CSV** or share as PDF
- Summary stats: total sales, collected, outstanding

### 📸 Camera Rental Module *(Photographer role only)*
- Separate **Rental Nav Bar** with 4 tabs: Rentals, Items, Customers, Orders
- **Rental Items**: Add camera gear with photos, pricing, and categories
- **Rental Sales**: Create rental bookings with from/to date-time pickers
- **Rental Customers**: Manage rental-specific customer contacts
- **Rental Orders**: View and manage all rental orders with status
- **Rental Sale Menu**: Quick context sheet for instant returns, status changes, and invoice generation
- Rental sale detail with full edit, payment tracking, and PDF generation

### 👤 Profile
- **Profile photo** — pick, crop, and persist your avatar across the entire app
- Avatar displayed in the NavBar header and profile page in real-time
- First-letter initial shown when no photo is set (with role-aware gradient)
- Edit name, phone, email, UPI ID, and business role inline
- Passcode management (setup / change / remove)
- Rental visibility toggle for the camera rental module

### 💾 Data Backup, Local Storage & Security
- **On-Device Local Backups Manager** — view all local backup files saved on device with timestamps and size metrics; restore or delete individual local copies with one tap
- **Recent Backup Audit Logs** — historical audit trail tracking timestamp, record count, file size, encryption state, and status indicators
- **End-to-End Encrypted Backups (E2EE)** — secure backup payloads with a custom secret PIN (AES encryption) before saving locally or uploading to cloud
- **Share to WhatsApp / Direct Chat** — export instant database snapshots directly to WhatsApp, email, or chat apps via native share sheet
- **Import JSON Backup File** — system file picker integration to import and validate any `.json` backup file from Downloads or external storage
- **Database Maintenance Service** — compact and maintain Hive database boxes for maximum read/write performance

### 🌗 Dark & Light Theme
- Full **dark mode and light mode** support across all screens
- Animated theme toggle (`RotationTransition` + `FadeTransition`) on all pages
- Enhanced accessibility: crisp text contrast, dedicated card borders, and readable financial labels in both modes
- Theme preference persisted across sessions

### ⚡ High-Hz Refresh Rate & Multi-GPU Acceleration Engine
- **Universal Multi-GPU Support** — natively optimized for Qualcomm Adreno, ARM Mali, ARM Immortalis, Apple Silicon, PowerVR, and x86/x86_64 emulator virtual renderers
- **Dynamic Display Refresh Rates** — full hardware synchronization supporting **60Hz, 90Hz, 120Hz, 144Hz, 165Hz**, and adaptive **LTPO/VRR variable refresh rate**
- **Hardware-Direct Surface Pipeline** — configured with `io.flutter.embedding.android.RenderMode: surface` for lowest latency Direct Hardware Composer compositing
- **Anti-Throttling Display Synchronization** — auto-inspects hardware display modes and applies maximum panel refresh rate on Android `WindowManager.LayoutParams`, automatically re-enforced in `onResume()` to counter OEM aggressive throttling (Samsung OneUI, OnePlus OxygenOS, Xiaomi MIUI)
- **iOS ProMotion 120Hz** — configured with `CADisableMinimumFrameDurationOnPhone` enabled for smooth 120fps motion on iPhone Pro models and iPad Pro
- **Profile Performance Diagnostics** — live GPU & Display Performance monitor card in the Profile page displaying current panel refresh rate, supported hardware modes, and one-tap refresh rate re-synchronization
- **Large Heap & Screen Density Resilience** — `largeHeap="true"` and `<supports-screens>` for smooth frame budgets on 2K/4K/QHD+ high-density displays

---

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| **Framework** | Flutter 3.x / Dart 3.x |
| **Local Database** | Hive 2.x + hive_flutter |
| **Cloud Sync & Auth** | Google Sign-In (`google_sign_in`), Google Drive API (`googleapis`) |
| **Background Scheduling** | Workmanager (`workmanager`) |
| **Notifications** | Flutter Local Notifications (`flutter_local_notifications`) |
| **State Management** | StatefulWidget + ValueNotifier |
| **Animations** | Lottie (`lottie`), flutter_animate, confetti |
| **PDF Generation** | pdf, printing, pdfx, syncfusion_flutter_pdfviewer |
| **Charts** | fl_chart |
| **Authentication** | local_auth (biometrics), flutter_secure_storage |
| **Images** | image_picker, image_cropper, flutter_image_compress |
| **QR Code** | qr_flutter, barcode |
| **Calendar** | table_calendar |
| **Sharing** | share_plus, url_launcher |
| **Icons** | font_awesome_flutter, hugeicons, iconsax, unicons |
| **CSV Export** | csv, file_saver |
| **Misc** | intl, path_provider, shared_preferences, package_info_plus, http |

---

## 📂 Project Structure

```
bizmate/
├── lib/
│   ├── main.dart                     # App entry, splash screen, routing
│   ├── models/                       # Hive data models (Sale, Customer, Product…)
│   ├── screens/                      # All feature screens
│   │   ├── nav_bar_page.dart         # Main 6-tab shell with IndexedStack persistence
│   │   ├── home_page.dart            # Sales feed, status filter chips, quick search
│   │   ├── dashboard_page.dart       # Net profit, revenue vs expenses, fl_chart PnL curves
│   │   ├── expenses_page.dart        # Expense management, categories, receipt tracking
│   │   ├── customers_page.dart       # Customer directory, WhatsApp automation, agreements
│   │   ├── products_page.dart        # Package catalog, pricing bundles, drag reorder
│   │   ├── sale_detail_screen.dart   # Edit sale, payment progress, dynamic UPI QR trigger
│   │   ├── pdf_preview_screen.dart   # Invoice viewer, UPI QR action, sharing
│   │   ├── profile_page.dart         # Business identity, UPI config, biometric & theme
│   │   ├── backup_screen.dart        # Google Drive cloud sync & local backup manager
│   │   ├── Camera rental page/       # Dedicated camera rental gear & bookings module
│   │   └── ...
│   ├── widgets/                      # Reusable UI components
│   │   ├── dynamic_upi_qr_dialog.dart# Counter checkout UPI QR modal & link sharing
│   │   ├── advanced_search_bar.dart  # Multi-parameter search & calendar filter
│   │   ├── sale_options_menu.dart    # Contextual actions, UPI collect, PDF share
│   │   └── ...
│   ├── services/                     # Business logic & data services
│   └── utils/                        # Helpers, constants, extensions
├── assets/
│   ├── images/                       # Logo, app images
│   ├── icons/                        # Custom icons
│   └── fonts/                        # Roboto font
├── android/                          # Android native config
├── ios/                              # iOS native config
├── pubspec.yaml                      # Dependencies & asset declarations
└── README.md
```

---

## ⚙️ Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.x
- Dart ≥ 3.x
- Android Studio / Xcode / VS Code with Flutter extension

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/Vishnu1017/BizMate.git
cd BizMate

# 2. Install dependencies
flutter pub get

# 3. Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# 4. Run on a connected device or emulator
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

### Build iOS IPA

```bash
flutter build ipa --release
```

---

## 📸 Screenshots

### 🔐 Authentication & Security

<table>
  <tr>
    <td align="center"><b>Login</b></td>
    <td align="center"><b>Signup</b></td>
    <td align="center"><b>Passcode Setup</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/Login_page.png" width="220"/></td>
    <td><img src="assets/screenshots/Signup_page.png" width="220"/></td>
    <td><img src="assets/screenshots/passcode_in_profile_page1.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Passcode (2)</b></td>
    <td align="center"><b>Passcode (3)</b></td>
    <td></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/passcode_in_profile_page2.png" width="220"/></td>
    <td><img src="assets/screenshots/passcode_in_profile_page3.png" width="220"/></td>
    <td></td>
  </tr>
</table>

---

### 🏠 Home & Dashboard

<table>
  <tr>
    <td align="center"><b>Home Page</b></td>
    <td align="center"><b>Dashboard</b></td>
    <td align="center"><b>Full Sales View</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/Home_page.png" width="220"/></td>
    <td><img src="assets/screenshots/dashborad.png" width="220"/></td>
    <td><img src="assets/screenshots/complete_page.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Sales View (scrolled)</b></td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/complete_page1.png" width="220"/></td>
    <td></td>
    <td></td>
  </tr>
</table>

---

### 🛒 Sales Management

<table>
  <tr>
    <td align="center"><b>New Sale</b></td>
    <td align="center"><b>New Sale (step 2)</b></td>
    <td align="center"><b>Add Products to Sale</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/add_new_sale.png" width="220"/></td>
    <td><img src="assets/screenshots/add_new_sale1.png" width="220"/></td>
    <td><img src="assets/screenshots/add_new_sale2.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Select Products</b></td>
    <td align="center"><b>Edit Sale</b></td>
    <td align="center"><b>Edit Sale (step 2)</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/select_products.png" width="220"/></td>
    <td><img src="assets/screenshots/edit_sale1.png" width="220"/></td>
    <td><img src="assets/screenshots/edit_sale2.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Sale Details</b></td>
    <td align="center"><b>Sale Details (scrolled)</b></td>
    <td align="center"><b>Delete Confirmation</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/view_details.png" width="220"/></td>
    <td><img src="assets/screenshots/view_details1.png" width="220"/></td>
    <td><img src="assets/screenshots/delete_pop.png" width="220"/></td>
  </tr>
</table>

---

### 💳 Payment History

<table>
  <tr>
    <td align="center"><b>Payment Timeline</b></td>
    <td></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/payment_history.png" width="220"/></td>
    <td></td>
  </tr>
</table>

---

### 📦 Products / Items

<table>
  <tr>
    <td align="center"><b>Items List</b></td>
    <td align="center"><b>Add New Item</b></td>
    <td align="center"><b>Add Item (step 2)</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/add_new_items.png.png" width="220"/></td>
    <td><img src="assets/screenshots/add_new_item.png" width="220"/></td>
    <td><img src="assets/screenshots/add_new_item1.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Package / Bundle View</b></td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/package_page.png" width="220"/></td>
    <td></td>
    <td></td>
  </tr>
</table>

---

### 👥 Customers

<table>
  <tr>
    <td align="center"><b>Customer List</b></td>
    <td align="center"><b>WhatsApp Actions</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/customer_page.png" width="220"/></td>
    <td><img src="assets/screenshots/customer_whatsapp.png" width="220"/></td>
  </tr>
</table>

---

### 📅 Calendar & Booking

<table>
  <tr>
    <td align="center"><b>Booking Calendar</b></td>
    <td align="center"><b>Date Selection</b></td>
    <td align="center"><b>Date Range Picker</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/booking_calendar.png" width="220"/></td>
    <td><img src="assets/screenshots/date selection.png" width="220"/></td>
    <td><img src="assets/screenshots/date_selecting_range.png" width="220"/></td>
  </tr>
</table>

---

### 🚚 Delivery Tracker

<table>
  <tr>
    <td align="center"><b>Delivery Tracker</b></td>
    <td align="center"><b>Delivery Status</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/Delviery_tracker1.png" width="220"/></td>
    <td><img src="assets/screenshots/Delviery_tracker2.png" width="220"/></td>
  </tr>
</table>

---

### 📸 Camera Rental Module

<table>
  <tr>
    <td align="center"><b>Camera Rental Home</b></td>
    <td align="center"><b>Rental Sale</b></td>
    <td align="center"><b>Rental Sale (details)</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/camera_rental_page.png" width="220"/></td>
    <td><img src="assets/screenshots/rental_sale.png" width="220"/></td>
    <td><img src="assets/screenshots/rental_sale1.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Add Rental Gear</b></td>
    <td align="center"><b>Add Gear (step 2)</b></td>
    <td align="center"><b>Add Gear (step 3)</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/add_rental_gear.png" width="220"/></td>
    <td><img src="assets/screenshots/add_rental_gear1.png" width="220"/></td>
    <td><img src="assets/screenshots/add_rental_gear2.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Rental Items List</b></td>
    <td align="center"><b>Rental Customers</b></td>
    <td align="center"><b>Rental Orders</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/rentak_items.png" width="220"/></td>
    <td><img src="assets/screenshots/rental_customer.png" width="220"/></td>
    <td><img src="assets/screenshots/rental_order.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Order Details</b></td>
    <td align="center"><b>Order Details (2)</b></td>
    <td align="center"><b>Edit Rental</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/rental_order1.png" width="220"/></td>
    <td><img src="assets/screenshots/rental_order2.png" width="220"/></td>
    <td><img src="assets/screenshots/rental_edit1.png" width="220"/></td>
  </tr>
</table>

---

### 👤 Profile

<table>
  <tr>
    <td align="center"><b>Profile Page</b></td>
    <td align="center"><b>Profile (scrolled)</b></td>
    <td align="center"><b>Edit Profile</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/profile_page1.png" width="220"/></td>
    <td><img src="assets/screenshots/profile_page2.png" width="220"/></td>
    <td><img src="assets/screenshots/profile_page_editing1.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Edit Profile (2)</b></td>
    <td align="center"><b>Edit Profile (3)</b></td>
    <td></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/profile_page_editing2.png" width="220"/></td>
    <td><img src="assets/screenshots/profile_page_editing3.png" width="220"/></td>
    <td></td>
  </tr>
</table>

---

## 📈 Roadmap

- [x] Dark & Light theme with instant toggle
- [x] Animated theme toggle (`RotationTransition` + `FadeTransition`) on all pages
- [x] Theme toggle available on login/signup screen
- [x] Profile photo — pick, crop, and persist avatar across the app
- [x] Payment status filter chips (All / PAID / PARTIAL / DUE) on home page
- [x] Camera rental module for photographers
- [x] WhatsApp integration with message templates
- [x] Release Agreement PDF generation
- [x] Biometric authentication
- [x] Sales report with charts and CSV export
- [x] Payment history timeline
- [x] Delivery tracker
- [x] Local data backup & restore
- [x] Premium Business Analytics splash screen with centered showcase deck
- [x] Modern Lottie Letter 'B' vector animation with cybernetic orbital aura
- [x] Cloud sync and backup (Google Drive with direct OAuth 2.0, zero Firebase)
- [x] Non-restricted `driveFileScope` security compliance & privacy-first storage
- [x] Cloud Restore Browser with remote backup management (inspect, restore, delete)
- [x] End-to-End Encrypted Backups (E2EE with secret PIN)
- [x] Scheduled automatic background backups (Workmanager Daily, Weekly, Monthly)
- [x] On-demand "Test Auto-Sync" background verification
- [x] Network-aware backup options (Wi-Fi only vs. Any Network)
- [x] Background backup completion notifications
- [x] On-device local backups manager & historical audit logs
- [x] WhatsApp direct chat export & system JSON file picker import
- [x] GST-compliant PDF invoices with NPCI UPI QR code
- [x] High-resolution Accepted UPI App badges on invoices (Google Pay, PhonePe, Paytm, BHIM)
- [x] Dark & Light theme financial contrast and accessibility polish
- [x] Expense tracking module embedded directly in bottom navbar (Tab index 2)
- [x] Real-time Net Profit & PnL Financial Dashboard with dual-view spline analytics
- [x] Dynamic UPI QR code generator, interactive counter checkout dialog & payment link sharing
- [x] Universal 5-Tier mobile and tablet responsiveness (<350px very small up to >600px tablets)
- [x] Zero-lag IndexedStack tab state persistence and scroll retention
- [ ] Multi-device real-time sync
- [ ] Push notifications for upcoming bookings and overdue payments
- [ ] Custom invoice branding (logo, colors, header)
- [ ] Multi-language / localization support

---

## 🤝 Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'feat: add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

Please make sure your code follows the existing style and passes `flutter analyze` with no issues.

---

## 👤 Author

**Vishnu Chandan**
- 🐙 GitHub: [@Vishnu1017](https://github.com/Vishnu1017)
- 📧 Email: [playroll.vish@gmail.com](mailto:playroll.vish@gmail.com)

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<p align="center">Made with ❤️ using Flutter</p>
