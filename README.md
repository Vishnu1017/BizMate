<h1 align="center">
  <img src="assets/images/bizmate_logo.JPG" width="80" height="80" style="border-radius:20px"/><br/>
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
  <img src="https://img.shields.io/badge/version-1.0.34-blue" alt="Version"/>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart"/>
</p>

---

## 🧾 About BizMate

**BizMate** is a powerful, offline-first Flutter application built for **photographers, freelancers, and small business owners**. It provides a complete suite of tools to manage sales, customers, products, camera rental gear, bookings, payments, and business reports — all from a single beautifully designed app.

Built with **Hive** for lightning-fast local storage, BizMate works entirely offline. It supports **dark and light themes**, **biometric authentication**, **GST-compliant PDF invoices**, **UPI QR codes**, **WhatsApp messaging**, and a dedicated **Camera Rental module** for photographers.

---

## ✨ Features

### 🔐 Authentication & Security
- Email/phone login with **passcode protection**
- **Biometric authentication** (Fingerprint / Face ID) on Android & iOS
- Session management with **auto-login**
- Role-based signup: **Photographer, Sales, Manager**, and more
- Secure passcode setup, change, and removal from profile

### 🏠 Dashboard & Home
- Animated stats summary (Total Sales, Revenue, Outstanding Dues)
- Recent sales list with customer info, status chips, and payment progress
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

### 🌗 Dark & Light Theme
- Full **dark mode and light mode** support across all screens
- Theme-aware gradients, chip colors, card surfaces, and shadows
- Persistent theme preference stored locally

---

## 📁 Project Structure

```
bizmate/
├── lib/
│   ├── main.dart                       # App entry point, Hive init, theme setup
│   ├── models/                         # Hive data models
│   │   ├── sale.dart
│   │   ├── product.dart
│   │   ├── customer.dart
│   │   ├── rental_item.dart
│   │   └── rental_sale_model.dart
│   ├── screens/                        # All app screens
│   │   ├── auth_gate_screen.dart       # Login / Signup / Passcode
│   │   ├── login_screen.dart
│   │   ├── nav_bar_page.dart           # Main bottom navigation
│   │   ├── home_page.dart              # Sales dashboard / home
│   │   ├── dashboard_page.dart         # Stats and analytics overview
│   │   ├── new_sale_screen.dart        # Create / edit a sale
│   │   ├── sale_detail_screen.dart     # Sale detail + payment management
│   │   ├── select_items_screen.dart    # Product selection for a sale
│   │   ├── products_page.dart          # Products / Items management
│   │   ├── customers_page.dart         # Customer directory
│   │   ├── payment_history_page.dart
│   │   ├── CalendarPage.dart
│   │   ├── DeliveryTrackerPage.dart
│   │   ├── SalesReportPage.dart
│   │   ├── profile_page.dart           # Profile, passcode, theme toggle
│   │   ├── pdf_preview_screen.dart
│   │   ├── rental_pdf_preview_screen.dart
│   │   └── Camera rental page/
│   │       ├── camera_rental_nav_bar.dart
│   │       ├── camera_rental.dart
│   │       ├── rental_items.dart
│   │       ├── rental_customers_page.dart
│   │       ├── rental_orders_page.dart
│   │       ├── rental_add_customer_page.dart
│   │       ├── rental_cart_preview_page.dart
│   │       ├── add_rental_item_page.dart
│   │       ├── edit_rental_item_page.dart
│   │       ├── rental_sale_detail_screen.dart
│   │       └── view_rental_details_page.dart
│   ├── widgets/                        # Reusable UI components
│   └── utils/
│       └── app_theme.dart              # AppColors, ThemeExtension, isDark helpers
├── assets/
│   ├── images/                         # App logo, branding
│   ├── icons/                          # GPay, PhonePe, Paytm icons
│   ├── fonts/                          # Roboto
│   └── screenshots/                    # App screenshots
├── android/
├── ios/
├── pubspec.yaml
└── README.md
```

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter 3.x** | Cross-platform UI framework |
| **Dart 3.x** | Programming language |
| **Hive + Hive Flutter** | Offline-first local database |
| **fl_chart** | Revenue and analytics charts |
| **pdf + printing** | GST invoice and agreement PDF generation |
| **pdfx / syncfusion_flutter_pdfviewer** | PDF preview |
| **qr_flutter + barcode** | UPI QR code generation |
| **local_auth** | Biometric fingerprint / Face ID |
| **flutter_secure_storage** | Secure passcode storage |
| **image_picker + image_cropper** | Profile and rental item photos |
| **flutter_image_compress** | Image optimization |
| **share_plus** | Share PDFs via WhatsApp, email, etc. |
| **url_launcher** | Phone calls and WhatsApp deep links |
| **table_calendar** | Booking calendar UI |
| **flutter_local_notifications** | Local push notifications |
| **flutter_animate + confetti** | Micro-animations and celebrations |
| **hugeicons + unicons + iconsax** | Rich icon libraries |
| **lottie** | Lottie animation support |
| **csv** | Sales report CSV export |
| **intl** | Date/time formatting |
| **shared_preferences** | Theme and session persistence |
| **file_picker / file_saver** | File import/export |

---

## 🚀 Getting Started

### Prerequisites
- Flutter **3.x** or higher
- Dart **3.x**
- Android **5.0+** (API 21+) or iOS **12+**
- Xcode (for iOS builds)

### Installation

```bash
git clone https://github.com/Vishnu1017/BizMate.git
cd BizMate
flutter pub get
```

### Running the App

```bash
flutter run
```

### Building Release Versions

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requires Xcode + Apple Developer account)
flutter build ios --release

# Web
flutter build web --release
```

### Regenerate Hive Adapters (if models change)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📸 Screenshots

### 🔐 Splash & Authentication

<table>
  <tr>
    <td align="center"><b>Splash Screen</b></td>
    <td align="center"><b>Passcode Setup</b></td>
    <td align="center"><b>Passcode Step 2</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/SplashScreen.png" width="220"/></td>
    <td><img src="assets/screenshots/passcode_in_profile_page.png" width="220"/></td>
    <td><img src="assets/screenshots/passcode_in_profile_page1.png" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><b>Passcode Change</b></td>
    <td align="center"><b>Passcode Remove</b></td>
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
- [x] Camera rental module for photographers
- [x] WhatsApp integration with message templates
- [x] Release Agreement PDF generation
- [x] Biometric authentication
- [x] Sales report with charts and CSV export
- [x] Payment history timeline
- [x] Delivery tracker
- [ ] Cloud sync and backup (Firebase / Supabase)
- [ ] Multi-device support
- [ ] Notifications for upcoming bookings and overdue payments
- [ ] Custom invoice branding (logo, colors, header)
- [ ] Expense tracking module
- [ ] Multi-language / localization support

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
