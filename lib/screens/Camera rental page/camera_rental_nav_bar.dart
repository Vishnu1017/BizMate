// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:bizmate/screens/Camera%20rental%20page/camera_rental.dart';
import 'package:bizmate/screens/Camera%20rental%20page/rental_items.dart';
import 'package:flutter/material.dart';
import 'rental_orders_page.dart';
import 'add_rental_item_page.dart';
import 'rental_customers_page.dart';

class CameraRentalNavBar extends StatefulWidget {
  final String userName;
  final String userPhone; // Add this
  final String userEmail;
  const CameraRentalNavBar({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
  });

  @override
  State<CameraRentalNavBar> createState() => _CameraRentalNavBarState();
}

class _CameraRentalNavBarState extends State<CameraRentalNavBar> {
  int _currentIndex = 0;

  final List<String> _titles = [
    "Camera Rental Sales",
    "Orders",
    "Rental Item",
    "Customers",
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      CameraRentalPage(
        userName: widget.userName,
        userPhone: widget.userPhone,
        userEmail: widget.userEmail,
      ),
      RentalOrdersPage(userEmail: widget.userEmail),
      RentalItems(userEmail: widget.userEmail),
      RentalCustomersPage(userEmail: widget.userEmail),
    ];
  }

  Widget _buildAddRentalButton() {
    if (_currentIndex != 2) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5.0, left: 16.0, right: 16.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_a_photo, color: Colors.white, size: 24),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Add Rental Item',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddRentalItemPage()),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _titles[_currentIndex],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pages[_currentIndex],
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildAddRentalButton(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.05,
          vertical: 8,
        ),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (int newIndex) {
              setState(() {
                _currentIndex = newIndex;
              });
            },
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedItemColor: const Color(0xFF1A237E),
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt_outlined),
                activeIcon: Icon(Icons.camera_alt),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag_outlined),
                activeIcon: Icon(Icons.shopping_bag),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_box_outlined),
                activeIcon: Icon(Icons.add_box),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_alt_outlined),
                activeIcon: Icon(Icons.people_alt),
                label: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
