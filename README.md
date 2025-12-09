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
  body {
    background: #0e0f14;
    font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI",
      Roboto, sans-serif;
  }

  .screenshots {
    max-width: 1200px;
    margin: auto;
    padding: 32px 16px;
    color: #fff;
  }

  .screenshots h2 {
    font-size: 28px;
    margin-bottom: 24px;
  }

  .section {
    margin-bottom: 44px;
  }

  .section-title {
    font-size: 20px;
    margin-bottom: 14px;
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .section-title::after {
    content: "";
    flex: 1;
    height: 1px;
    background: linear-gradient(
      to right,
      rgba(255, 255, 255, 0.5),
      transparent
    );
  }

  .slider {
    display: flex;
    gap: 18px;
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    scroll-behavior: smooth;
    padding-bottom: 12px;
  }

  .slider::-webkit-scrollbar {
    display: none;
  }

  .slide {
    flex: 0 0 240px;
    scroll-snap-align: center;
    background: rgba(255, 255, 255, 0.08);
    border-radius: 18px;
    padding: 8px;
    border: 1px solid rgba(255, 255, 255, 0.15);
    backdrop-filter: blur(12px);
    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.6);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
  }

  .slide:hover {
    transform: translateY(-8px) scale(1.03);
    box-shadow: 0 18px 45px rgba(0, 0, 0, 0.85);
  }

  .slide img {
    width: 100%;
    border-radius: 14px;
    display: block;
  }

  .slider {
    cursor: grab;
  }

  .slider:active {
    cursor: grabbing;
  }
</style>

<div class="screenshots">
  <h2>📸 Screenshots</h2>

  <!-- Splash & Home -->
  <div class="section">
    <div class="section-title">🚀 Splash & Home</div>
    <div class="slider">
      <div class="slide"><img src="assets/screenshots/SplashScreen.png"width="250" /></div>
      <div class="slide"><img src="assets/screenshots/Home_page.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/dashborad.png" width="250"/></div>
    </div>
  </div>

  <!-- Items -->
  <div class="section">
    <div class="section-title">📦 Items</div>
    <div class="slider">
      <div class="slide"><img src="assets/screenshots/add_new_item.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/add_new_item1.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/add_new_items.png.png" width="250"/></div>
    </div>
  </div>

  <!-- Sales -->
  <div class="section">
    <div class="section-title">💰 Sales</div>
    <div class="slider">
      <div class="slide"><img src="assets/screenshots/add_new_sale.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/add_new_sale1.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/add_new_sale2.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/edit_sale1.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/edit_sale2.png" width="250"/></div>
    </div>
  </div>

  <!-- Rentals -->
  <div class="section">
    <div class="section-title">📷 Rentals</div>
    <div class="slider">
      <div class="slide"><img src="assets/screenshots/add_rental_gear.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/add_rental_gear1.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/add_rental_gear2.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/rentak_items.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/rental_customer.png"width="250" /></div>
      <div class="slide"><img src="assets/screenshots/rental_order.png"width="250" /></div>
      <div class="slide"><img src="assets/screenshots/rental_sale.png" width="250"/></div>
    </div>
  </div>

  <!-- Customers -->
  <div class="section">
    <div class="section-title">👤 Customers</div>
    <div class="slider">
      <div class="slide"><img src="assets/screenshots/customer_page.png"width="250" /></div>
      <div class="slide"><img src="assets/screenshots/customer_whatsapp.png" width="250"/></div>
    </div>
  </div>

  <!-- Booking -->
  <div class="section">
    <div class="section-title">📅 Booking & Dates</div>
    <div class="slider">
      <div class="slide"><img src="assets/screenshots/booking_calendar.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/date selection.png" width="250"/></div>
      <div class="slide"><img src="assets/screenshots/date_selecting_range.png" width="250"/></div>
    </div>
  </div>

  <!-- Delivery -->
  <div class="section">
    <div class="section-title">🚚 Delivery</div>
    <div class="slider">
      <div class="slide"><img src="assets/screenshots/Delviery_tracker1.png"width="250"/></div>
      <div class="slide"><img src="assets/screenshots/Delviery_tracker2.png" width="250"/></div>
    </div>
  </div>
</div>
