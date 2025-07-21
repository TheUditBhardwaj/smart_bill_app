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
        primarySwatch: Colors.indigo, // A base color for the app
        scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Light blue-gray background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFC3DAF9), // Pastel blue for app bar
          foregroundColor: Color(0xFF334155), // Darker text on app bar
          elevation: 0,
        ),
        cardTheme: CardThemeData( // Corrected from CardTheme to CardThemeData
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            elevation: 3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF6B7280), width: 2), // Slightly darker on focus
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        fontFamily: 'Inter', // Assuming Inter font is available or similar sans-serif
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
        _showMessage('Bill generated and email sent successfully!');
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
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
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
      _showMessage('$quantity x ${product.name} added to bill.');
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
      _showMessage('${itemToRemove.name} removed from bill.');
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
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _activeTabIndex = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeTabIndex == 0 ? const Color(0xFF81B2F9) : const Color(0xFFE0E7F4), // Pastel blue/gray
                      foregroundColor: _activeTabIndex == 0 ? Colors.white : const Color(0xFF334155),
                    ),
                    child: const Text('Dashboard'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _activeTabIndex = 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeTabIndex == 1 ? const Color(0xFF81B2F9) : const Color(0xFFE0E7F4),
                      foregroundColor: _activeTabIndex == 1 ? Colors.white : const Color(0xFF334155),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Inventory', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildProductForm(),
            const SizedBox(height: 24),
            Text('Existing Products', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _products.isEmpty
                ? const Text('No products in inventory. Add some!')
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Price: \$${product.price.toStringAsFixed(2)} | Quantity: ${product.quantity}', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFFF9C381)), // Pastel yellow
                          onPressed: () {
                            // Populate form for editing
                            _productNameController.text = product.name;
                            _productPriceController.text = product.price.toString();
                            _productQuantityController.text = product.quantity.toString();
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Edit Product'),
                                  content: _buildProductForm(initialProduct: product),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Cancel'),
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
                          icon: const Icon(Icons.delete, color: Color(0xFFF98181)), // Pastel red
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
          decoration: const InputDecoration(labelText: 'Product Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _productPriceController,
          decoration: const InputDecoration(labelText: 'Price'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _productQuantityController,
          decoration: const InputDecoration(labelText: 'Quantity'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
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
              Navigator.of(context).pop(); // Close dialog if it's an edit
              _clearProductForm();
            } else {
              _showMessage('Please fill all product fields correctly.', isError: true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF81B2F9), // Pastel blue
            foregroundColor: Colors.white,
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Details', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildCustomerForm(),
            const SizedBox(height: 24),
            Text('Existing Customers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _customers.isEmpty
                ? const Text('No customers added yet.')
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _customers.length,
              itemBuilder: (context, index) {
                final customer = _customers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Phone: ${customer.phone} | Email: ${customer.email}', style: const TextStyle(color: Colors.grey)),
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
          decoration: const InputDecoration(labelText: 'Customer Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customerPhoneController,
          decoration: const InputDecoration(labelText: 'Phone'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customerEmailController,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
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
            backgroundColor: const Color(0xFF98D8AA), // Pastel green
            foregroundColor: Colors.white,
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Products for Bill', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Customer>(
                    value: _selectedCustomer,
                    decoration: const InputDecoration(
                      labelText: 'Select Customer',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Select a Customer --')),
                      ..._customers.map((customer) =>
                          DropdownMenuItem(
                            value: customer,
                            child: Text('${customer.name} (${customer.email})'),
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
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _productSearchTerm = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Available Products', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _products.isEmpty
                      ? const Text('No products found or available.')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredProducts.length, // Using the getter here
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index]; // Using the getter here
                      final TextEditingController qtyController = TextEditingController(text: '1');
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Price: \$${product.price.toStringAsFixed(2)} | Available: ${product.quantity}', style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: TextField(
                                  controller: qtyController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                  backgroundColor: const Color(0xFF81B2F9), // Pastel blue
                                  foregroundColor: Colors.white,
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bill Preview', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  if (_selectedCustomer != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'Customer: ${_selectedCustomer!.name} (${_selectedCustomer!.email})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  _currentBill.isEmpty
                      ? const Text('No items in the bill yet.')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentBill.length,
                    itemBuilder: (context, index) {
                      final item = _currentBill[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('\$${item.price.toStringAsFixed(2)} x ${item.billedQuantity}', style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Text('\$${(item.price * item.billedQuantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Color(0xFFF98181)), // Pastel red
                                onPressed: () => _removeProductFromBill(item.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 30, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total:', style: Theme.of(context).textTheme.titleLarge),
                      Text('\$${_calculateTotal().toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _generateAndSendBill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF98D8AA), // Pastel green
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50), // Make button full width
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
