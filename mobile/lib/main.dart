
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Port 5001 par verified Flask backend.
// Android emulator ke liye 10.0.2.2.
// Windows Chrome ke liye --dart-define se URL set karenge.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5001',
);

void main() {
  runApp(const SellBuddyApp());
}

String money(num amount) => '₹${amount.toStringAsFixed(0)}';

class SellBuddyApp extends StatefulWidget {
  const SellBuddyApp({super.key});

  @override
  State<SellBuddyApp> createState() => _SellBuddyAppState();
}

class _SellBuddyAppState extends State<SellBuddyApp> {
  ThemeMode themeMode = ThemeMode.system;
  Map<String, dynamic>? customer;
  String? token;

  void changeTheme() {
    setState(() {
      themeMode = themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  void login(Map<String, dynamic> response) {
    setState(() {
      customer = Map<String, dynamic>.from(response['customer']);
      token = response['token']?.toString();
    });
  }

  Future<void> logout() async {
    final oldToken = token;

    setState(() {
      customer = null;
      token = null;
    });

    if (oldToken != null) {
      try {
        await http.post(
          Uri.parse('$apiBaseUrl/api/auth/logout'),
          headers: {'Authorization': 'Bearer $oldToken'},
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        // Local logout still completes if server is unavailable.
      }
    }
  }

  ThemeData appTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7154EB),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: dark
          ? const Color(0xFF101019)
          : const Color(0xFFF7F7FC),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF1C1C29) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SellBuddy',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: themeMode,
      home: ShopScreen(
        customer: customer,
        token: token,
        onLogin: login,
        onLogout: logout,
        onThemeChange: changeTheme,
      ),
    );
  }
}

// ===================== MODELS =====================

class Product {
  final int id;
  final String name;
  final String description;
  final String category;
  final String imageUrl;
  final double price;
  final int stock;

  Product.fromJson(Map<String, dynamic> json)
      : id = (json['id'] as num).toInt(),
        name = (json['name'] ?? '').toString(),
        description = (json['description'] ?? '').toString(),
        category = (json['category'] ?? 'Other').toString(),
        imageUrl = (json['image_url'] ?? '').toString(),
        price = (json['price'] as num).toDouble(),
        stock = (json['stock'] as num).toInt();
}

class CartItem {
  final Product product;
  int quantity;

  CartItem(this.product, this.quantity);
}

// ===================== AUTHENTICATION =====================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  bool signup = false;
  bool loading = false;
  bool showPassword = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate() || loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final endpoint = signup ? 'signup' : 'login';

      final body = <String, dynamic>{
        'email': email.text.trim(),
        'password': password.text,
      };

      if (signup) {
        body['name'] = name.text.trim();
        body['phone'] = phone.text.trim();
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid server response');
      }

      if (response.statusCode != 200 &&
          response.statusCode != 201) {
        throw Exception(
          data['error'] ?? 'Authentication failed',
        );
      }

      if (data['token'] == null || data['customer'] == null) {
        throw Exception('Incomplete login response');
      }

      if (!mounted) return;

      Navigator.pop(context, data);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SellBuddy Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.shopping_bag_rounded,
                          size: 36,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        signup
                            ? 'Create your account'
                            : 'Welcome back!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        signup
                            ? 'Join SellBuddy and start shopping.'
                            : 'Log in to your SellBuddy account.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      if (signup) ...[
                        TextFormField(
                          controller: name,
                          textCapitalization:
                              TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().length < 8) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null ||
                              !value.contains('@') ||
                              !value.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: password,
                        obscureText: !showPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                showPassword = !showPassword;
                              });
                            },
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 15),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.error,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: loading ? null : submit,
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                signup
                                    ? 'Create Account'
                                    : 'Log In',
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  signup = !signup;
                                  error = null;
                                });
                              },
                        child: Text(
                          signup
                              ? 'Already have an account? Log In'
                              : "Don't have an account? Sign Up",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== SHOP =====================

class ShopScreen extends StatefulWidget {
  final Map<String, dynamic>? customer;
  final String? token;
  final ValueChanged<Map<String, dynamic>> onLogin;
  final Future<void> Function() onLogout;
  final VoidCallback onThemeChange;

  const ShopScreen({
    super.key,
    required this.customer,
    required this.token,
    required this.onLogin,
    required this.onLogout,
    required this.onThemeChange,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<Product> products = [];
  final Map<int, CartItem> cart = {};

  final search = TextEditingController();
  final tracking = TextEditingController();

  bool loading = true;
  bool placingOrder = false;
  bool trackingLoading = false;
  bool ordersLoading = false;
  String? ordersError;
  List<Map<String, dynamic>> myOrders = [];

  String? error;
  String? trackingResult;
  String category = 'All';

  int tab = 0;
  int? lastOrderId;

  int get itemCount => cart.values.fold(
        0,
        (sum, item) => sum + item.quantity,
      );

  double get total => cart.values.fold(
        0.0,
        (sum, item) =>
            sum + item.product.price * item.quantity,
      );

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  @override
  void dispose() {
    search.dispose();
    tracking.dispose();
    super.dispose();
  }

  Future<void> loadProducts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/products'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server error ${response.statusCode}');
      }

      final list = jsonDecode(response.body) as List;

      if (!mounted) return;

      setState(() {
        products = list
            .map(
              (item) => Product.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Cannot connect to SellBuddy server.\n$e';
        loading = false;
      });
    }
  }

  Future<void> openAccount() async {
    if (widget.customer == null) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
      );

      if (result != null && mounted) {
        widget.onLogin(result);
        if (tab == 2) loadMyOrders();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to SellBuddy!'),
          ),
        );
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 65,
                ),
                const SizedBox(height: 15),
                Text(
                  'Hi, ${widget.customer!['name']}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.customer!['email']}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  '${widget.customer!['phone']}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await widget.onLogout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void addToCart(Product product) {
    if (product.stock <= 0) return;

    setState(() {
      if (cart.containsKey(product.id)) {
        final item = cart[product.id]!;

        if (item.quantity < product.stock) {
          item.quantity++;
        }
      } else {
        cart[product.id] = CartItem(product, 1);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.shopping_bag,
              color: Color(0xFF7154EB),
            ),
            SizedBox(width: 10),
            Text(
              'SellBuddy',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 23,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: openAccount,
            icon: Icon(
              widget.customer == null
                  ? Icons.person_outline
                  : Icons.account_circle,
            ),
          ),
          IconButton(
            tooltip: 'Change Theme',
            onPressed: widget.onThemeChange,
            icon: Icon(
              dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: loadProducts,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => setState(() => tab = 1),
            icon: Badge(
              isLabelVisible: itemCount > 0,
              label: Text('$itemCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: tab == 0
          ? loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : error != null
                  ? buildError()
                  : buildShop()
          : tab == 1
              ? buildCart()
              : buildOrders(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) {
          setState(() => tab = index);
          if (index == 2) loadMyOrders();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: itemCount > 0,
              label: Text('$itemCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Orders',
          ),
        ],
      ),
    );
  }

  Widget buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 65),
            const SizedBox(height: 15),
            const Text(
              'Connection Problem',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildShop() {
    final categories = [
      'All',
      ...products.map((p) => p.category).toSet(),
    ];

    final query = search.text.trim().toLowerCase();

    final visible = products.where((p) {
      final matchesCategory =
          category == 'All' || p.category == category;

      final matchesSearch =
          p.name.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();

    return RefreshIndicator(
      onRefresh: loadProducts,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7053EF),
                          Color(0xFF9E78F9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THE NEW WAY TO SHOP',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Find something\namazing today.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Discover products you will love.',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Easy Shopping • Cash on Delivery',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search products',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Explore Categories',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 45,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final current = categories[index];

                        return ChoiceChip(
                          label: Text(current),
                          selected: category == current,
                          onSelected: (_) {
                            setState(() => category = current);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Featured Products',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('${visible.length} items'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No products found'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                12, 0, 12, 20,
              ),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.crossAxisExtent >= 700
                          ? 4
                          : 2;

                  return SliverGrid.builder(
                    itemCount: visible.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 315,
                    ),
                    itemBuilder: (context, index) {
                      return productCard(visible[index]);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget productCard(Product product) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: product.imageUrl.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 55,
                          ),
                        )
                      : Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 50,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      product.stock > 0
                          ? 'POPULAR'
                          : 'SOLD OUT',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.category.toUpperCase(),
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  money(product.price),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: product.stock > 0
                        ? () => addToCart(product)
                        : null,
                    child: Text(
                      product.stock > 0
                          ? 'Add to Cart'
                          : 'Sold Out',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== CART =====================

  Widget buildCart() {
    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 15),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Discover something amazing!'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => setState(() => tab = 0),
              child: const Text('Explore Products'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'My Shopping Cart',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: cart.entries.map((entry) {
              final item = entry.value;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 75,
                          height: 80,
                          child: item.product.imageUrl.isEmpty
                              ? const Icon(Icons.shopping_bag)
                              : Image.network(
                                  item.product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(
                                    Icons.shopping_bag,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(money(item.product.price)),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      item.quantity--;

                                      if (item.quantity <= 0) {
                                        cart.remove(entry.key);
                                      }
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                  ),
                                ),
                                Text('${item.quantity}'),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      if (item.quantity <
                                          item.product.stock) {
                                        item.quantity++;
                                      }
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(fontSize: 17),
                    ),
                    Text(
                      money(total),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        placingOrder ? null : checkout,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      placingOrder
                          ? 'Placing Order...'
                          : 'Checkout • Cash on Delivery',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===================== ORDER TRACKING =====================

  Future<void> trackOrder() async {
    final id = int.tryParse(tracking.text.trim());

    if (id == null || id <= 0) {
      setState(() {
        trackingResult = 'Please enter a valid Order ID.';
      });
      return;
    }

    setState(() {
      trackingLoading = true;
      trackingResult = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/orders/$id'),
        headers: {
          if (widget.token != null)
            'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 404) {
        setState(() {
          trackingResult = 'Order not found.';
        });
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Server error ${response.statusCode}');
      }

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      setState(() {
        trackingResult =
            'Order #${data['id']}\n\n'
            'Status: ${data['status']}\n\n'
            'Total: ${money(data['total'] as num)}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        trackingResult = 'Unable to track order:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() => trackingLoading = false);
      }
    }
  }


  // ===================== MY ORDERS =====================

  Future<void> loadMyOrders() async {
    final currentToken = widget.token;

    if (currentToken == null) {
      if (!mounted) return;
      setState(() {
        myOrders = [];
        ordersError = null;
        ordersLoading = false;
      });
      return;
    }

    setState(() {
      ordersLoading = true;
      ordersError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/my-orders'),
        headers: {
          'Authorization': 'Bearer $currentToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted || widget.token != currentToken) return;

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Server error ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as List;

      setState(() {
        myOrders = data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        ordersLoading = false;
      });
    } catch (e) {
      if (!mounted || widget.token != currentToken) return;
      setState(() {
        ordersError = e.toString().replaceFirst('Exception: ', '');
        ordersLoading = false;
      });
    }
  }

  Widget buildOrders() {
    if (widget.token == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 70),
              const SizedBox(height: 16),
              const Text(
                'Log in to see your orders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: openAccount,
                icon: const Icon(Icons.login),
                label: const Text('Log In / Sign Up'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadMyOrders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: loadMyOrders,
                tooltip: 'Refresh orders',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Your personal shopping history'),
          const SizedBox(height: 16),

          if (ordersLoading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (ordersError != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      ordersError!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loadMyOrders,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (myOrders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 60),
                    SizedBox(height: 14),
                    Text(
                      'No orders yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your new purchases will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...myOrders.map((order) {
              final items = (order['items'] as List? ?? []);
              final orderId = order['id'];
              final status = (order['status'] ?? '').toString();
              final amount = (order['total'] as num?) ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order #$orderId',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(label: Text(status)),
                        ],
                      ),
                      Text(
                        (order['created_at'] ?? '').toString(),
                      ),
                      const Divider(height: 25),
                      ...items.map((rawItem) {
                        final item =
                            Map<String, dynamic>.from(rawItem as Map);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['product_name']} ? ${item['quantity']}',
                                ),
                              ),
                              Text(
                                money(
                                  ((item['price'] as num?) ?? 0) *
                                  ((item['quantity'] as num?) ?? 0),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Order Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            money(amount),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          tracking.text = '$orderId';
                          setState(() {
                            trackingResult = null;
                          });
                          trackOrder();
                        },
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Check Order Status'),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Track an Order',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tracking,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Order ID',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: trackingLoading ? null : trackOrder,
            icon: const Icon(Icons.search),
            label: Text(
              trackingLoading ? 'Checking...' : 'Track Order',
            ),
          ),
          if (trackingLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (trackingResult != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(trackingResult!),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildLegacyTrackingOrders() {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 25),
          Center(
            child: CircleAvatar(
              radius: 55,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.local_shipping_outlined,
                size: 65,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Track Your Order',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Stay updated with your shopping journey.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter Order ID',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: tracking,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Example: 1',
                      prefixIcon:
                          Icon(Icons.receipt_long_outlined),
                    ),
                  ),
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed:
                        trackingLoading ? null : trackOrder,
                    icon: const Icon(Icons.search),
                    label: Text(
                      trackingLoading
                          ? 'Checking...'
                          : 'Track My Order',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (lastOrderId != null) ...[
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: () {
                tracking.text = '$lastOrderId';
                trackOrder();
              },
              icon: const Icon(Icons.history),
              label: Text(
                'Track Last Order #$lastOrderId',
              ),
            ),
          ],
          if (trackingLoading) ...[
            const SizedBox(height: 20),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
          if (trackingResult != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: scheme.primary,
                      size: 38,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      trackingResult!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== CHECKOUT =====================

  Future<void> checkout() async {
    if (cart.isEmpty || placingOrder) return;

    if (widget.token == null) {
      await openAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in, then continue checkout.'),
        ),
      );
      return;
    }

    final name = TextEditingController(
      text: widget.customer?['name']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: widget.customer?['phone']?.toString() ?? '',
    );
    final address = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delivery Details'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon:
                              Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value == null ||
                                    value.trim().isEmpty
                                ? 'Enter your name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon:
                              Icon(Icons.phone_outlined),
                        ),
                        validator: (value) =>
                            value == null ||
                                    value.trim().length < 8
                                ? 'Enter a valid phone number'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: address,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Address',
                          prefixIcon:
                              Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) =>
                            value == null ||
                                    value.trim().isEmpty
                                ? 'Enter delivery address'
                                : null,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Payment Method: Cash on Delivery',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Total: ${money(total)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Place Order'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) return;

      setState(() => placingOrder = true);

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/api/orders'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
          body: jsonEncode({
            'customer_name': name.text.trim(),
            'phone': phone.text.trim(),
            'address': address.text.trim(),
            'items': cart.values.map((item) {
              return {
                'product_id': item.product.id,
                'quantity': item.quantity,
              };
            }).toList(),
          }),
        ).timeout(const Duration(seconds: 15));

        final data =
            jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode != 201) {
          throw Exception(
            data['error'] ?? 'Order failed',
          );
        }

        if (!mounted) return;

        final orderId =
            (data['order_id'] as num).toInt();

        setState(() {
          lastOrderId = orderId;
          tracking.text = '$orderId';
          trackingResult = null;
          cart.clear();
          tab = 2;
        });

        await loadProducts();
        await loadMyOrders();

        if (!mounted) return;

        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Order Placed!'),
              content: Text(
                'Order ID: #$orderId\n\n'
                'Total: ${money(data['total'] as num)}\n\n'
                'Track your order in the Orders tab.',
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not place order: $e'),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => placingOrder = false);
        }
      }
    } finally {
      name.dispose();
      phone.dispose();
      address.dispose();
    }
  }
}
