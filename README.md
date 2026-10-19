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
  <img src="https://img.shields.io/badge/version-1.0.51-blue" alt="Version"/>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green" alt="Platform"/>
  <img src="https://img.shields.io/badge/Storage-Hive%20(Offline)-orange" alt="Storage"/>
</p>

---

## 🧾 About BizMate

**BizMate** is a powerful, **offline-first** Flutter application built for **photographers, freelancers, and small business owners**. It provides a complete suite of tools to manage sales, customers, products, camera rental gear, bookings, payments, and business reports — all from a single beautifully designed app.

Built with **Hive** for lightning-fast local storage, BizMate works entirely offline with no internet required for day-to-day operations. It features a premium **Business Analytics splash screen** with cinematic animations, supports **dark and light themes**, **biometric authentication**, **GST-compliant PDF invoices**, **UPI QR codes**, **WhatsApp messaging**, and a dedicated **Camera Rental module** tailored for photographers.

---

## ✨ Features at a Glance

| Module | Highlights |
|---|---|
| 🔐 **Auth & Security** | Passcode, Biometrics (Face ID / Fingerprint), Auto-login |
| 🏠 **Dashboard** | Animated stats, filter chips, quick actions |
| 🛒 **Sales** | GST invoices, advance payments, payment timeline |
| 📦 **Products** | Drag-reorder, categories, quick search |
| 👥 **Customers** | WhatsApp integration, call, Release Agreement PDF |
| 📅 **Calendar** | Visual booking calendar, date-range picker |
| 🚚 **Delivery** | Status tracker with animated progress |
| 💳 **Payments** | Timeline view, mode icons, due/paid highlights |
| 📊 **Reports** | fl_chart analytics, CSV/PDF export |
| 📁 **PDF Invoice** | UPI QR, GST-compliant, shareable |
| 📸 **Camera Rental** | Full rental module for photographers |
| 👤 **Profile** | Avatar, role, passcode management |
| 💾 **Backup** | Local data backup & restore |
| 🌗 **Theme** | Instant dark/light toggle on every screen |

---

## 🚀 Feature Details

### 🔐 Authentication & Security
- Email/phone login with **passcode protection**
- **Biometric authentication** (Fingerprint / Face ID) on Android & iOS
- Session management with **auto-login**
- Role-based signup: **Photographer, Sales, Manager**, and more
- Secure passcode setup, change, and removal from profile
- **Theme toggle on login & signup screen** — switch dark/light before logging in

### 🏠 Dashboard & Home
- Animated stats summary (Total Sales, Revenue, Outstanding Dues)
- Recent sales list with customer info, status badges, and payment progress
- **Payment status filter chips** — instantly filter by **All / PAID / PARTIAL / DUE**
- Filter chips stack with search and date range filters simultaneously
- Quick action buttons for adding sales and viewing reports
- Dark / Light theme toggle with persistent preference

### 🛒 Sales Management
- Create and manage **GST-compliant sales/invoices**
- Add multiple products per sale with quantity and pricing
- Track **advance payments**, **balance due**, and **payment history timeline**
- Edit sales, update received amounts, change payment mode
- Mark delivery status and due dates per sale
- Full **sale detail screen** with payment breakdown and progress ring

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

### 💳 Payment History
- Chronological **payment timeline** per sale
- Animated progress bar showing % paid
- Payment mode icons (Cash, UPI, Card, Online, Bank)
- Balance due highlighted in red; fully paid shown in green

### 📊 Sales Report
- Revenue analytics with **fl_chart** bar and line charts
- Filter by date range, payment status, and customer
- Export report as **CSV** or share as PDF
- Summary stats: total sales, collected, outstanding

### 📁 PDF Invoice
- Generate beautiful **GST-compliant PDF invoices**
- Embedded **UPI QR codes** (GPay, PhonePe, Paytm)
- Share invoices via WhatsApp, email, or save to device
- **Release Agreement PDF** generation for clients

### 📸 Camera Rental Module *(Photographer role only)*
- Separate **Rental Nav Bar** with 4 tabs: Rentals, Items, Customers, Orders
- **Rental Items**: Add camera gear with photos, pricing, and categories
- **Rental Sales**: Create rental bookings with from/to date-time pickers
- **Rental Customers**: Manage rental-specific customer contacts
- **Rental Orders**: View and manage all rental orders with status
- Rental sale detail with full edit, payment tracking, and PDF generation

### 👤 Profile
- **Profile photo** — pick, crop, and persist your avatar across the entire app
- Avatar displayed in the NavBar header and profile page in real-time
- First-letter initial shown when no photo is set (with role-aware gradient)
- Edit name, phone, email, and business role inline
- Passcode management (setup / change / remove)
- Rental visibility toggle for the camera rental module

### 💾 Backup & Restore
- Local data backup to device storage
- Restore from a previous backup file
- Export and import Hive database snapshots

### 🌗 Dark & Light Theme
- Full **dark mode and light mode** support across all screens
- Animated theme toggle (`RotationTransition` + `FadeTransition`) on all pages
- Theme preference persisted across sessions

---

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| **Framework** | Flutter 3.x / Dart 3.x |
| **Local Database** | Hive 2.x + hive_flutter |
| **State Management** | StatefulWidget + ValueNotifier |
| **PDF Generation** | pdf, printing, pdfx, syncfusion_flutter_pdfviewer |
| **Charts** | fl_chart |
| **Authentication** | local_auth (biometrics), flutter_secure_storage |
| **Images** | image_picker, image_cropper, flutter_image_compress |
| **QR Code** | qr_flutter, barcode |
| **Calendar** | table_calendar |
| **Notifications** | flutter_local_notifications |
| **Sharing** | share_plus, url_launcher |
| **Animations** | flutter_animate, lottie, confetti |
| **Icons** | font_awesome_flutter, hugeicons, iconsax, unicons |
| **CSV Export** | csv, file_saver |
| **Misc** | intl, path_provider, shared_preferences, package_info_plus |

---

## 📂 Project Structure

```
bizmate/
├── lib/
│   ├── main.dart                     # App entry, splash screen, routing
│   ├── models/                       # Hive data models (Sale, Customer, Product…)
│   ├── screens/                      # All feature screens
│   │   ├── home_page.dart
│   │   ├── dashboard_page.dart
│   │   ├── profile_page.dart
│   │   ├── backup_screen.dart
│   │   ├── Camera rental page/
│   │   └── ...
│   ├── widgets/                      # Reusable UI components
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
- [x] Premium Business Analytics splash screen with cinematic animations
- [ ] Cloud sync and backup (Firebase / Supabase)
- [ ] Multi-device support
- [ ] Push notifications for upcoming bookings and overdue payments
- [ ] Custom invoice branding (logo, colors, header)
- [ ] Expense tracking module
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
