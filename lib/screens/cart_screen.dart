import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../utils/date_formatter.dart';
import 'package:tsena_servisy/components/custom_app_bar.dart';
import 'package:tsena_servisy/models/cart_item.dart';
import 'package:tsena_servisy/models/enums.dart';
import 'package:tsena_servisy/services/cart_service.dart';
import 'package:tsena_servisy/screens/payment/payment_screen.dart';
import 'package:tsena_servisy/services/payment_service.dart';
import 'package:tsena_servisy/services/api_service.dart';
import 'package:tsena_servisy/services/user_service.dart';
import 'package:tsena_servisy/services/notification_service.dart';

class CartScreen extends StatefulWidget {
  final int municipalityId;
  
  const CartScreen({
    super.key, 
    required this.municipalityId,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _nifController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nifController.dispose();
    super.dispose();
  }

  Future<void> _showNifDialog() async {
    final nif = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          tr('nif_title'),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('nif_instruction'),
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nifController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(),
                decoration: InputDecoration(
                  labelText: tr('nif_label'),
                  hintText: tr('nif_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('nif_required');
                  }
                  if (value.trim().length < 9) {
                    return tr('nif_length_error');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(tr('cancel'), style: GoogleFonts.outfit()),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState?.validate() == true) {
                Navigator.pop(context, _nifController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(tr('confirm'), style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
    
    if (nif != null && nif.isNotEmpty) {
      _navigateToPayment(nif);
    }
  }

  void _navigateToPayment(String nif) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => PaymentService(municipalityId: widget.municipalityId.toString()),
          child: PaymentScreen(
            nif: nif,
            municipalityId: widget.municipalityId,
          ),
        ),
      ),
    );
  }

  Future<void> _proceedToPayment() async {
    setState(() => _isLoading = true);
    
    try {
      // Get user profile
      final userProfile = await UserService.getUserProfile();
      final userId = userProfile?['user_id']?.toString();
      
      if (userId == null || userId.isEmpty) {
        throw Exception(tr('user_not_connected'));
      }

      // Check if user already has NIF
      final apiService = ApiService();
      final nifResponse = await apiService.getUserNif(userId);
      
      if (!nifResponse.success) {
        throw Exception(tr('nif_verification_error', namedArgs: {'error': nifResponse.error ?? 'Unknown error'}));
      }

      String? userNif = nifResponse.data;
      
      if (userNif != null && userNif.isNotEmpty) {
        // User already has NIF, go directly to payment
        _navigateToPayment(userNif);
      } else {
        // User doesn't have NIF, show modal to collect it
        await _showNifDialog();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
          context,
          '${tr('error')}: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: tr('cart_title'),
        showBackButton: true,
        gradientColors: [
          Theme.of(context).primaryColor,
          Theme.of(context).primaryColor.withBlue(200),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      tr('empty_cart'),
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D1E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('add_items_instruction'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16, top: 16),
                    child: Column(
                      children: List.generate(cart.items.length, (index) {
                        final item = cart.items[index];
                        return _buildCartItem(item, cart);
                      }),
                    ),
                  ),
                ),
                _buildTotalSection(cart),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartService cart) {
    final local = item.local;
    // Formatage des dates géré par DateFormatter

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.store_mall_directory_rounded,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('local_number_format', namedArgs: {'number': local.number}),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: const Color(0xFF1A1D1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        local.zone['nom'] ?? tr('unknown_zone'),
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (local.zone['fokotany_name'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          tr('fokotany_prefix', namedArgs: {'name': local.zone['fokotany_name']}),
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  ),
                  onPressed: () => cart.removeItem(item),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${tr('contract_type_label', namedArgs: {'type': item.contractType == ContractType.daily ? tr('daily').toUpperCase() : tr('annual').toUpperCase()})}${item.contractType == ContractType.annual && item.contractEndDate != null ? tr('expires_on', namedArgs: {'date': DateFormatter.formatDate(item.contractEndDate!)}) : ''}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1D1E),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (item.contractType == ContractType.daily)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('selected_dates'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (item.selectedDates ?? [])
                          .map((date) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormatter.formatDate(date),
                                      style: GoogleFonts.inter(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        final newDates = List<DateTime>.from(item.selectedDates ?? []);
                                        newDates.removeWhere((d) => d.isAtSameMomentAs(date));
                                        final cartService = Provider.of<CartService>(context, listen: false);
                                        cartService.updateItemDates(item, newDates);
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (item.contractType == ContractType.annual)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('duration_label'),
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          tr('months_count', namedArgs: {'count': (item.numberOfMonths ?? 1).toString()}),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1D1E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('monthly_rate'),
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${(item.local.typeLocal?['tarif'] ?? 0.0).toStringAsFixed(0)} ${tr('ar_per_month')}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
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
  }

  Widget _buildTotalSection(CartService cart) {
    // Vérifier s'il y a des contrats annuels dans le panier
    final hasAnnualContracts = cart.items.any((item) => item.contractType == ContractType.annual);
    final hasDailyContracts = cart.items.any((item) => item.contractType == ContractType.daily);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAnnualContracts) ...[
            Text(
              tr('monthly_payments'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1D1E),
              ),
            ),
            const SizedBox(height: 12),
            ...cart.items.where((item) => item.contractType == ContractType.annual).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tr('local_number_format', namedArgs: {'number': item.local.number})} (${tr('months_count', namedArgs: {'count': item.numberOfMonths.toString()})})',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${(item.local.typeLocal?['tarif'] ?? 0.0).toStringAsFixed(0)} ${tr('ar_per_month')}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1D1E),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          if (hasDailyContracts) ...[
            Text(
              tr('one_time_payment'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1D1E),
              ),
            ),
            const SizedBox(height: 12),
            ...cart.items.where((item) => item.contractType == ContractType.daily).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tr('local_number_format', namedArgs: {'number': item.local.number})} (${tr('days_count', namedArgs: {'count': (item.selectedDates?.length ?? 0).toString()})})',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      tr('amount_format', namedArgs: {'amount': item.totalAmount.toStringAsFixed(0)}),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1D1E),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _proceedToPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      tr('validate_order'),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
