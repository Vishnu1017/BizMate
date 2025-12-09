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
  :root {
    --bg: #0e0f13;
    --card: rgba(255, 255, 255, 0.08);
    --border: rgba(255, 255, 255, 0.15);
    --text: #ffffff;
    --sub: #b3b3b3;
    --accent: linear-gradient(135deg, #7f5cff, #0abde3);
  }

  body {
    background: var(--bg);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }

  .showcase {
    max-width: 1200px;
    margin: auto;
    padding: 32px 16px;
    color: var(--text);
  }

  .showcase h2 {
    font-size: 28px;
    margin-bottom: 8px;
  }

  .showcase p {
    color: var(--sub);
    margin-bottom: 32px;
  }

  .section {
    margin-bottom: 48px;
  }

  .section-title {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 20px;
    margin-bottom: 20px;
  }

  .section-line {
    flex: 1;
    height: 1px;
    background: linear-gradient(to right, rgba(255,255,255,0.4), transparent);
  }

  .shot-row {
    display: flex;
    gap: 20px;
    overflow-x: auto;
    padding-bottom: 12px;
    scrollbar-width: none;
  }

  .shot-row::-webkit-scrollbar {
    display: none;
  }

  .shot {
    flex: 0 0 240px;
    background: var(--card);
    backdrop-filter: blur(14px);
    border-radius: 20px;
    padding: 10px;
    border: 1px solid var(--border);
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6);
    transition: transform 0.35s ease, box-shadow 0.35s ease;
  }

  .shot:hover {
    transform: translateY(-10px) scale(1.03);
    box-shadow: 0 20px 50px rgba(0, 0, 0, 0.9);
  }

  .shot img {
    width: 100%;
    border-radius: 14px;
    display: block;
  }

  .glow {
    position: relative;
  }

  .glow::after {
    content: "";
    position: absolute;
    inset: -1px;
    border-radius: 20px;
    background: var(--accent);
    opacity: 0.35;
    filter: blur(18px);
    z-index: -1;
  }
</style>

<div class="showcase">
  <h2>📸 App Experience</h2>
  <p>A complete walkthrough of the system – sales, rentals, customers, and tools.</p>

  <!-- Splash & Home -->
  <div class="section">
    <div class="section-title">
      🚀 Splash & Home <span class="section-line"></span>
    </div>
    <div class="shot-row">
      <div class="shot glow"><img src="assets/screenshots/SplashScreen.png"></div>
      <div class="shot glow"><img src="assets/screenshots/Home_page.png"></div>
      <div class="shot glow"><img src="assets/screenshots/dashboard.png"></div>
    </div>
  </div>

  <!-- Items -->
  <div class="section">
    <div class="section-title">
      📦 Inventory <span class="section-line"></span>
    </div>
    <div class="shot-row">
      <div class="shot glow"><img src="assets/screenshots/add_new_item.png"></div>
      <div class="shot glow"><img src="assets/screenshots/add_new_item1.png"></div>
      <div class="shot glow"><img src="assets/screenshots/add_new_items.png"></div>
    </div>
  </div>

  <!-- Sales -->
  <div class="section">
    <div class="section-title">
      💰 Sales <span class="section-line"></span>
    </div>
    <div class="shot-row">
      <div class="shot glow"><img src="assets/screenshots/add_new_sale.png"></div>
      <div class="shot glow"><img src="assets/screenshots/add_new_sale1.png"></div>
      <div class="shot glow"><img src="assets/screenshots/add_new_sale2.png"></div>
      <div class="shot"><img src="assets/screenshots/edit_sale1.png"></div>
      <div class="shot"><img src="assets/screenshots/edit_sale2.png"></div>
    </div>
  </div>

  <!-- Rentals -->
  <div class="section">
    <div class="section-title">
      📷 Rentals <span class="section-line"></span>
    </div>
    <div class="shot-row">
      <div class="shot glow"><img src="assets/screenshots/add_rental_gear.png"></div>
      <div class="shot glow"><img src="assets/screenshots/add_rental_gear1.png"></div>
      <div class="shot glow"><img src="assets/screenshots/add_rental_gear2.png"></div>
      <div class="shot"><img src="assets/screenshots/rental_items.png"></div>
      <div class="shot"><img src="assets/screenshots/rental_customer.png"></div>
      <div class="shot"><img src="assets/screenshots/rental_order.png"></div>
      <div class="shot"><img src="assets/screenshots/rental_sale.png"></div>
    </div>
  </div>

  <!-- Customers -->
  <div class="section">
    <div class="section-title">
      👤 Customers <span class="section-line"></span>
    </div>
    <div class="shot-row">
      <div class="shot glow"><img src="assets/screenshots/customer_page.png"></div>
      <div class="shot glow"><img src="assets/screenshots/customer_whatsapp.png"></div>
    </div>
  </div>

  <!-- Profile -->
  <div class="section">
    <div class="section-title">
      🔐 Profile & Security <span class="section-line"></span>
    </div>
    <div class="shot-row">
      <div class="shot glow"><img src="assets/screenshots/profile_page1.png"></div>
      <div class="shot"><img src="assets/screenshots/profile_page_editing1.png"></div>
      <div class="shot"><img src="assets/screenshots/passcode_in_profile_page.png"></div>
    </div>
  </div>
</div>
