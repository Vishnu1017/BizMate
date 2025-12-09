<h1 align="center">📒 BizMate</h1>
<h3 align="center">A Flutter-based billing and accounting app</h3>

<p align="center">
  <a href="https://github.com/Vishnu1017/ClickAccount">
    <img src="https://img.shields.io/github/stars/Vishnu1017/ClickAccount?style=social" alt="GitHub Stars">
  </a>
  <a href="https://github.com/Vishnu1017/ClickAccount">
    <img src="https://img.shields.io/github/forks/Vishnu1017/ClickAccount?style=social" alt="GitHub Forks">
  </a>
  <a href="https://github.com/Vishnu1017/ClickAccount">
    <img src="https://img.shields.io/github/issues/Vishnu1017/ClickAccount" alt="Issues">
  </a>
  <a href="https://github.com/Vishnu1017/ClickAccount">
    <img src="https://img.shields.io/github/license/Vishnu1017/ClickAccount" alt="License">
  </a>
</p>

<h2>🧾 About the App</h2>
<p><strong>BizMate</strong> is a Flutter application designed for small businesses, freelancers, and entrepreneurs to manage users, roles, customers, products, and invoices efficiently. It uses <strong>Hive</strong> for local offline-first storage and allows generating GST-compliant PDF invoices with embedded UPI QR codes.</p>

<h2>🔧 Features</h2>
<ul>
  <li>Login with email/phone and passcode</li>
  <li>Android biometric authentication (Fingerprint/Face ID)</li>
  <li>Session management with auto-login</li>
  <li>Role selection during signup (Photographer, Sales, Manager, etc.)</li>
  <li>Manage users, products, and customers locally using Hive</li>
  <li>Create, edit, and manage GST-compliant invoices</li>
  <li>Generate and share PDF invoices with UPI QR codes</li>
  <li>Camera Rental module (available only for <strong>Photographer</strong> role)</li>
  <li>Offline-first functionality for fast performance</li>
</ul>

<h2>📁 Project Structure</h2>
<pre>
lib/
├── models/          # Hive data models (User, Product, Invoice)
├── screens/         # App screens (Login, Signup, Dashboard, AuthGate, Passcode)
├── widgets/         # Reusable UI components
├── services/        # Business logic (PDF, Invoice generation, UPI QR)
└── main.dart        # App entry point
assets/              # Images, icons, fonts
android/
ios/
web/
</pre>

<h2>🚀 Getting Started</h2>

<h3>Prerequisites</h3>
<ul>
  <li>Flutter 3.x or higher</li>
  <li>Dart 3.x</li>
  <li>Android 5.0+ for biometric authentication</li>
</ul>

<h3>Installation</h3>
<pre>
git clone https://github.com/Vishnu1017/BizMate.git
cd BizMate
flutter pub get
</pre>

<h3>Running the App</h3>
<pre>flutter run</pre>

<h3>Building Release Versions</h3>
<pre>
flutter build apk    # Android
flutter build ios    # iOS (requires Xcode)
flutter build web    # Web
</pre>

<h2>🛠️ Technologies Used</h2>
<p>
  <a href="https://flutter.dev" target="_blank"><img src="https://www.vectorlogo.zone/logos/flutterio/flutterio-icon.svg" alt="Flutter" width="40" height="40" style="margin-right:10px"/></a>
  <a href="https://dart.dev" target="_blank"><img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/dart/dart-original.svg" alt="Dart" width="40" height="40" style="margin-right:10px"/></a>
  <a href="https://pub.dev/packages/hive" target="_blank"><img src="https://pub.dev/static/hash-3e5x4t/image/preview/hive.png" alt="Hive" width="40" height="40" style="margin-right:10px"/></a>
  <a href="https://www.w3.org/html/" target="_blank"><img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/html5/html5-original.svg" alt="HTML5" width="40" height="40"/></a>
</p>

<h2>📈 Roadmap</h2>
<ul>
  <li>Multi-user support</li>
  <li>Cloud sync and backup (optional)</li>
  <li>Analytics dashboard for invoices and revenue</li>
  <li>Custom themes and branding options</li>
</ul>

<h2>👤 Author</h2>
<ul>
  <li>Vishnu Chandan</li>
  <li>GitHub: <a href="https://github.com/Vishnu1017">Vishnu1017</a></li>
  <li>Email: (playroll.vish@gmail.com)</li>
</ul>

<h2>📄 License</h2>
<p>MIT License – see LICENSE file for details.</p>

<style>
  .screenshots-section {
    margin-top: 24px;
  }

  .screenshots-section h2 {
    font-size: 24px;
    margin-bottom: 16px;
  }

  .screenshots-group {
    margin-bottom: 32px;
  }

  .screenshots-group h3 {
    margin-bottom: 12px;
    font-size: 18px;
    color: #444;
  }

  .screenshots-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 16px;
  }

  .screenshot-card {
    background: #fff;
    border-radius: 12px;
    padding: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
    transition: transform 0.2s ease, box-shadow 0.2s ease;
  }

  .screenshot-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 18px rgba(0, 0, 0, 0.12);
  }

  .screenshot-card img {
    width: 100%;
    border-radius: 8px;
    display: block;
  }
</style>

<div class="screenshots-section">
  <h2>📸 App Screenshots</h2>

  <!-- Splash & Home -->
  <div class="screenshots-group">
    <h3>🚀 Splash & Home</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/SplashScreen.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/Home_page.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/dashboard.png" /></div>
    </div>
  </div>

  <!-- Items -->
  <div class="screenshots-group">
    <h3>📦 Items</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/add_new_item.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/add_new_item1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/add_new_items.png" /></div>
    </div>
  </div>

  <!-- Sales -->
  <div class="screenshots-group">
    <h3>💰 Sales</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/add_new_sale.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/add_new_sale1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/add_new_sale2.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/edit_sale1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/edit_sale2.png" /></div>
    </div>
  </div>

  <!-- Rentals -->
  <div class="screenshots-group">
    <h3>📷 Rentals</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/add_rental_gear.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/add_rental_gear1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/add_rental_gear2.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_items.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_customer.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_edit.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_edit1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_order.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_order1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_order2.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_sale.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/rental_sale1.png" /></div>
    </div>
  </div>

  <!-- Customer -->
  <div class="screenshots-group">
    <h3>👤 Customers</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/customer_page.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/customer_whatsapp.png" /></div>
    </div>
  </div>

  <!-- Booking -->
  <div class="screenshots-group">
    <h3>📅 Booking & Dates</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/booking_calendar.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/date_selection.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/date_selecting_range.png" /></div>
    </div>
  </div>

  <!-- Delivery -->
  <div class="screenshots-group">
    <h3>🚚 Delivery</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/Delivery_tracker1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/Delivery_tracker2.png" /></div>
    </div>
  </div>

  <!-- Profile -->
  <div class="screenshots-group">
    <h3>🙍 Profile & Security</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/profile_page1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/profile_page2.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/profile_page_editing1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/profile_page_editing2.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/profile_page_editing3.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/passcode_in_profile_page.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/passcode_in_profile_page1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/passcode_in_profile_page2.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/passcode_in_profile_page3.png" /></div>
    </div>
  </div>

  <!-- Misc -->
  <div class="screenshots-group">
    <h3>✨ Misc</h3>
    <div class="screenshots-grid">
      <div class="screenshot-card"><img src="assets/screenshots/select_products.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/view_details.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/view_details1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/delete_pop.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/complete_page.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/complete_page1.png" /></div>
      <div class="screenshot-card"><img src="assets/screenshots/camera_rental_page.png" /></div>
    </div>
  </div>
</div>
