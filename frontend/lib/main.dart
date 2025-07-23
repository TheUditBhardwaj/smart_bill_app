// lib/main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For JSON encoding/decoding

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Billing App',
      theme: ThemeData(
        brightness: Brightness.dark, // Set overall theme to dark
        primarySwatch: Colors.grey, // Using grey as primary swatch for shades
        scaffoldBackgroundColor: const Color(0xFF000000), // Pure Black background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000), // Pure Black app bar
          foregroundColor: Colors.white, // White text on app bar
          elevation: 0, // Flat design for app bar
        ),
        cardTheme: CardThemeData(
          elevation: 4, // Moderate elevation for depth
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: const Color(0xFF1A1A1A), // Dark grey for cards to provide contrast from pure black background
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            elevation: 5,
            backgroundColor: Colors.white, // White buttons for strong action
            foregroundColor: Colors.black, // Black text on white buttons
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0A0A0A), // Slightly lighter black for input fields
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white, width: 2), // White border on focus
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          labelStyle: const TextStyle(color: Colors.white70), // Light grey label text
          hintStyle: const TextStyle(color: Colors.white54), // Lighter grey hint text
        ),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(color: Colors.white),
        ),
      ),
      home: const SmartBillingHomePage(),
    );
  }
}

// Data Models (matching FastAPI Pydantic models)
class Product {
  final String? id;
  final String name;
  final double price;
  final int quantity;

  Product({this.id, required this.name, required this.price, required this.quantity});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      quantity: json['quantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}

class Customer {
  final String? id;
  final String name;
  final String phone;
  final String email;

  Customer({this.id, required this.name, required this.phone, required this.email});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
    };
  }
}

class BillItem {
  final String id; // Product ID
  final String name;
  final double price;
  int billedQuantity; // Can be modified in the bill

  BillItem({required this.id, required this.name, required this.price, required this.billedQuantity});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'billedQuantity': billedQuantity,
    };
  }
}

class SmartBillingHomePage extends StatefulWidget {
  const SmartBillingHomePage({super.key});

  @override
  State<SmartBillingHomePage> createState() => _SmartBillingHomePageState();
}

class _SmartBillingHomePageState extends State<SmartBillingHomePage> {
  // Base URL for your FastAPI backend
  final String _baseUrl = 'http://127.0.0.1:8000'; // Make sure this matches your backend URL

  List<Product> _products = [];
  List<Customer> _customers = [];
  List<BillItem> _currentBill = [];
  Customer? _selectedCustomer;
  String _productSearchTerm = '';
  String? _message;
  int _activeTabIndex = 0; // 0 for Dashboard, 1 for Create Bill

  // Controllers for ProductForm
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productPriceController = TextEditingController();
  final TextEditingController _productQuantityController = TextEditingController();

  // Controllers for CustomerForm
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData(); // Fetch initial data when the app starts
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productPriceController.dispose();
    _productQuantityController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    await _fetchProducts();
    await _fetchCustomers();
  }

  // --- Backend Integration Functions ---

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/products/'));
      if (response.statusCode == 200) {
        List<dynamic> productJson = jsonDecode(response.body);
        setState(() {
          _products = productJson.map((json) => Product.fromJson(json)).toList();
        });
      } else {
        _showMessage('Failed to load products: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('Error fetching products: $e', isError: true);
    }
  }

  Future<void> _addProduct(Product product) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/products/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(product.toJson()),
      );
      if (response.statusCode == 201) {
        _showMessage('Product added successfully!');
        _fetchProducts(); // Refresh product list
      } else {
        _showMessage('Failed to add product: ${response.body}', isError: true);
      }
    } catch (e) {
      _showMessage('Error adding product: $e', isError: true);
    }
  }

  Future<void> _updateProduct(Product product) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/products/${product.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(product.toJson()),
      );
      if (response.statusCode == 200) {
        _showMessage('Product updated successfully!');
        _fetchProducts(); // Refresh product list
      } else {
        _showMessage('Failed to update product: ${response.body}', isError: true);
      }
    } catch (e) {
      _showMessage('Error updating product: $e', isError: true);
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/products/$productId'));
      if (response.statusCode == 204) {
        _showMessage('Product deleted successfully!');
        _fetchProducts(); // Refresh product list
      } else {
        _showMessage('Failed to delete product: ${response.body}', isError: true);
      }
    } catch (e) {
      _showMessage('Error deleting product: $e', isError: true);
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/customers/'));
      if (response.statusCode == 200) {
        List<dynamic> customerJson = jsonDecode(response.body);
        setState(() {
          _customers = customerJson.map((json) => Customer.fromJson(json)).toList();
        });
      } else {
        _showMessage('Failed to load customers: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('Error fetching customers: $e', isError: true);
    }
  }

  Future<void> _addCustomer(Customer customer) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/customers/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(customer.toJson()),
      );
      if (response.statusCode == 201) {
        _showMessage('Customer added successfully!');
        _fetchCustomers(); // Refresh customer list
      } else {
        _showMessage('Failed to add customer: ${response.body}', isError: true);
      }
    } catch (e) {
      _showMessage('Error adding customer: $e', isError: true);
    }
  }

  Future<void> _generateAndSendBill() async {
    if (_currentBill.isEmpty) {
      _showMessage('Bill is empty. Please add products.');
      return;
    }
    if (_selectedCustomer == null) {
      _showMessage('Please select a customer for the bill.');
      return;
    }

    final billData = {
      'customer': _selectedCustomer!.toJson(),
      'items': _currentBill.map((item) => item.toJson()).toList(),
      'total': _calculateTotal(),
      'date': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD
      'time': DateTime.now().toIso8601String().split('T')[1].substring(0, 8), // HH:MM:SS
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate-and-send-bill/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(billData),
      );

      if (response.statusCode == 200) {
        _showMessage('Bill generated and email sent successfully! 📧');
        setState(() {
          _currentBill.clear();
          _selectedCustomer = null;
          _productSearchTerm = '';
        });
        _fetchProducts(); // Refresh product quantities
      } else {
        _showMessage('Failed to generate/send bill: ${response.body}', isError: true);
      }
    } catch (e) {
      _showMessage('Error generating/sending bill: $e', isError: true);
    }
  }

  // --- UI Logic Functions ---

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _message = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700, // Stronger red/green for alerts
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _addProductToBill(Product product, int quantity) {
    if (quantity <= 0) {
      _showMessage('Please enter a quantity greater than 0.');
      return;
    }
    if (quantity > product.quantity) {
      _showMessage('Not enough quantity for ${product.name}. Available: ${product.quantity}.', isError: true);
      return;
    }

    setState(() {
      final existingItemIndex = _currentBill.indexWhere((item) => item.id == product.id);

      if (existingItemIndex > -1) {
        _currentBill[existingItemIndex].billedQuantity += quantity;
      } else {
        _currentBill.add(BillItem(
          id: product.id!,
          name: product.name,
          price: product.price,
          billedQuantity: quantity,
        ));
      }
      // Optimistically update local product quantity for immediate UI feedback
      final productIndex = _products.indexWhere((p) => p.id == product.id);
      if (productIndex > -1) {
        _products[productIndex] = Product(
          id: product.id,
          name: product.name,
          price: product.price,
          quantity: product.quantity - quantity,
        );
      }
      _showMessage('$quantity x ${product.name} added to bill. ✅');
    });
  }

  void _removeProductFromBill(String productId) {
    setState(() {
      final itemToRemove = _currentBill.firstWhere((item) => item.id == productId);
      // Restore quantity to inventory (local update)
      final productIndex = _products.indexWhere((p) => p.id == productId);
      if (productIndex > -1) {
        _products[productIndex] = Product(
          id: _products[productIndex].id,
          name: _products[productIndex].name,
          price: _products[productIndex].price,
          quantity: _products[productIndex].quantity + itemToRemove.billedQuantity,
        );
      }
      _currentBill.removeWhere((item) => item.id == productId);
      _showMessage('${itemToRemove.name} removed from bill. 🗑️');
    });
  }

  double _calculateTotal() {
    return _currentBill.fold(0.0, (sum, item) => sum + (item.price * item.billedQuantity));
  }

  // Getter for filtered products, accessible throughout the state class
  List<Product> get _filteredProducts {
    return _products.where((product) =>
        product.name.toLowerCase().contains(_productSearchTerm.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Billing App'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _activeTabIndex = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeTabIndex == 0 ? Colors.white : const Color(0xFF1A1A1A), // White active, dark grey inactive
                      foregroundColor: _activeTabIndex == 0 ? Colors.black : Colors.white,
                      elevation: _activeTabIndex == 0 ? 8 : 2,
                    ),
                    child: const Text('Dashboard'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _activeTabIndex = 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeTabIndex == 1 ? Colors.white : const Color(0xFF1A1A1A),
                      foregroundColor: _activeTabIndex == 1 ? Colors.black : Colors.white,
                      elevation: _activeTabIndex == 1 ? 8 : 2,
                    ),
                    child: const Text('Create Bill'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _activeTabIndex == 0 ? _buildDashboardView() : _buildCreateBillView(),
      ),
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductManagementSection(),
          const SizedBox(height: 24),
          _buildCustomerManagementSection(),
        ],
      ),
    );
  }

  Widget _buildProductManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Inventory 📦', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            _buildProductForm(),
            const SizedBox(height: 30),
            Text('Existing Products', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _products.isEmpty
                ? const Text('No products in inventory. Add some!', style: TextStyle(color: Colors.white70))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  color: const Color(0xFF0A0A0A), // Even darker card for list items
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text('Price: \₹${product.price.toStringAsFixed(2)} | Quantity: ${product.quantity}', style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white), // White icon for edit
                          onPressed: () {
                            _productNameController.text = product.name;
                            _productPriceController.text = product.price.toString();
                            _productQuantityController.text = product.quantity.toString();
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: const Color(0xFF1A1A1A), // Dark background for dialog
                                  title: const Text('Edit Product', style: TextStyle(color: Colors.white)),
                                  content: _buildProductForm(initialProduct: product),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _clearProductForm();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white), // White icon for delete
                          onPressed: () => _deleteProduct(product.id!),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductForm({Product? initialProduct}) {
    if (initialProduct != null) {
      _productNameController.text = initialProduct.name;
      _productPriceController.text = initialProduct.price.toString();
      _productQuantityController.text = initialProduct.quantity.toString();
    } else {
      _clearProductForm();
    }

    return Column(
      children: [
        TextField(
          controller: _productNameController,
          decoration: const InputDecoration(labelText: 'Product Name', labelStyle: TextStyle(color: Colors.white70)),
          style: const TextStyle(color: Colors.white), // Text input color
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _productPriceController,
          decoration: const InputDecoration(labelText: 'Price', labelStyle: TextStyle(color: Colors.white70)),
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _productQuantityController,
          decoration: const InputDecoration(labelText: 'Quantity', labelStyle: TextStyle(color: Colors.white70)),
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            final name = _productNameController.text;
            final price = double.tryParse(_productPriceController.text);
            final quantity = int.tryParse(_productQuantityController.text);

            if (name.isNotEmpty && price != null && quantity != null) {
              if (initialProduct == null) {
                _addProduct(Product(name: name, price: price, quantity: quantity));
              } else {
                _updateProduct(Product(id: initialProduct.id, name: name, price: price, quantity: quantity));
              }
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              _clearProductForm();
            } else {
              _showMessage('Please fill all product fields correctly.', isError: true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          child: Text(initialProduct == null ? 'Add Product' : 'Update Product'),
        ),
      ],
    );
  }

  void _clearProductForm() {
    _productNameController.clear();
    _productPriceController.clear();
    _productQuantityController.clear();
  }

  Widget _buildCustomerManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Details 👥', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            _buildCustomerForm(),
            const SizedBox(height: 30),
            Text('Existing Customers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _customers.isEmpty
                ? const Text('No customers added yet.', style: TextStyle(color: Colors.white70))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customers.length,
              itemBuilder: (context, index) {
                final customer = _customers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  color: const Color(0xFF0A0A0A),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Phone: ${customer.phone} | Email: ${customer.email}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerForm() {
    return Column(
      children: [
        TextField(
          controller: _customerNameController,
          decoration: const InputDecoration(labelText: 'Customer Name', labelStyle: TextStyle(color: Colors.white70)),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _customerPhoneController,
          decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.white70)),
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _customerEmailController,
          decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white70)),
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            final name = _customerNameController.text;
            final phone = _customerPhoneController.text;
            final email = _customerEmailController.text;

            if (name.isNotEmpty && phone.isNotEmpty && email.isNotEmpty) {
              _addCustomer(Customer(name: name, phone: phone, email: email));
              _clearCustomerForm();
            } else {
              _showMessage('Please fill all customer fields.', isError: true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          child: const Text('Add Customer'),
        ),
      ],
    );
  }

  void _clearCustomerForm() {
    _customerNameController.clear();
    _customerPhoneController.clear();
    _customerEmailController.clear();
  }

  Widget _buildCreateBillView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Products for Bill 🛒', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<Customer>(
                    value: _selectedCustomer,
                    dropdownColor: const Color(0xFF1A1A1A), // Dark dropdown background
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Select Customer',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    // Add selectedItemBuilder to control how the selected item is displayed
                    selectedItemBuilder: (BuildContext context) {
                      return _customers.map<Widget>((Customer customer) {
                        return Align(
                          alignment: Alignment.centerLeft, // Align text to the left
                          child: Text(
                            '${customer.name} (${customer.email})',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            overflow: TextOverflow.ellipsis, // Ensure overflow handling
                            maxLines: 1, // Restrict to a single line
                          ),
                        );
                      }).toList();
                    },
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          '-- Select a Customer --',
                          style: TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1, // Also for the placeholder
                        ),
                      ),
                      ..._customers.map((customer) =>
                          DropdownMenuItem(
                            value: customer,
                            child: Text( // No need for Expanded here if selectedItemBuilder is used for display
                              '${customer.name} (${customer.email})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ),
                    ],
                    onChanged: (customer) {
                      setState(() {
                        _selectedCustomer = customer;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Products',
                      prefixIcon: Icon(Icons.search, color: Colors.white70),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _productSearchTerm = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text('Available Products', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _products.isEmpty
                      ? const Text('No products found or available.', style: TextStyle(color: Colors.white70))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final TextEditingController qtyController = TextEditingController(text: '1');
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        color: const Color(0xFF0A0A0A),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text('Price: \₹${product.price.toStringAsFixed(2)} | Available: ${product.quantity}', style: const TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: TextField(
                                  controller: qtyController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    fillColor: const Color(0xFF000000), // Pure black fill
                                    filled: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: product.quantity == 0
                                    ? null
                                    : () {
                                  final quantity = int.tryParse(qtyController.text);
                                  if (quantity != null) {
                                    _addProductToBill(product, quantity);
                                  } else {
                                    _showMessage('Please enter a valid quantity.', isError: true);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bill Preview 📝', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  if (_selectedCustomer != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Customer: ${_selectedCustomer!.name} (${_selectedCustomer!.email})',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                      ),
                    ),
                  _currentBill.isEmpty
                      ? const Text('No items in the bill yet.', style: TextStyle(color: Colors.white70))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentBill.length,
                    itemBuilder: (context, index) {
                      final item = _currentBill[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        color: const Color(0xFF0A0A0A),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text('\₹${item.price.toStringAsFixed(2)} x ${item.billedQuantity}', style: const TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              ),
                              Text('\₹${(item.price * item.billedQuantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.white), // White icon for remove
                                onPressed: () => _removeProductFromBill(item.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 30, thickness: 1, color: Colors.white54),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total:', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
                      Text('\₹${_calculateTotal().toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 24)), // White for total
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _generateAndSendBill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 55),
                      ),
                      child: const Text('Generate & Send Bill'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}