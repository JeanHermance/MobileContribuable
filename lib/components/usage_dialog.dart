import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/local_model.dart';

class UsageDialog extends StatefulWidget {
  final LocalModel local;
  final bool isAnnual;
  final int? numberOfMonths;
  final String initialValue;
  final Function(String)? onConfirm;

  const UsageDialog({
    super.key,
    required this.local,
    this.isAnnual = false,
    this.numberOfMonths,
    this.initialValue = '',
    this.onConfirm,
  });
  @override
  UsageDialogState createState() => UsageDialogState();
}

class UsageDialogState extends State<UsageDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usageController;
  late List<String> _suggestions;

  @override
  void initState() {
    super.initState();
    _usageController = TextEditingController(text: widget.initialValue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _suggestions = [
      'usage_suggestion_food'.tr(),
      'usage_suggestion_clothes'.tr(),
      'usage_suggestion_small_items'.tr(),
      'usage_suggestion_furniture'.tr(),
      'usage_suggestion_kitchen'.tr(),
      'usage_suggestion_other'.tr(),
    ];
    
    // S'assurer que la valeur par défaut est valide si elle est vide
    if (_usageController.text.isEmpty && _suggestions.isNotEmpty) {
      _usageController.text = _suggestions.first;
    }
  }

  @override
  void dispose() {
    _usageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête amélioré
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.business_center_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'usage_dialog_title'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1D1E),
                          ),
                        ),
                        Text(
                          'usage_dialog_subtitle'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text(
                'activity_type_label'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
              const SizedBox(height: 8),
              
              // Champ de saisie amélioré
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextFormField(
                  controller: _usageController,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF1A1D1E),
                  ),
                  decoration: InputDecoration(
                    hintText: 'usage_hint'.tr(),
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    suffixIcon: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey.shade600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.white,
                      elevation: 4,
                      onSelected: (String value) {
                        _usageController.text = value;
                      },
                      itemBuilder: (BuildContext context) {
                        return _suggestions
                            .map<PopupMenuItem<String>>((String value) {
                          return PopupMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.store_mall_directory_outlined,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  value,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF1A1D1E),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'usage_required_error'.tr();
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ),
              const SizedBox(height: 32),
              
              // Boutons d'action améliorés
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'cancel'.tr(),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() == true) {
                          widget.onConfirm?.call(_usageController.text);
                          Navigator.of(context).pop(_usageController.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shadowColor: Colors.transparent,
                      ),
                      child: Text(
                        'confirm'.tr(),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
