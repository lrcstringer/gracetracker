import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';

enum _Plan { monthly, annual, lifetime }

class PaywallScreen extends StatefulWidget {
  final VoidCallback onNext;
  const PaywallScreen({super.key, required this.onNext});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  _Plan _selectedPlan = _Plan.annual;
  bool _showContent = false;
  bool _showFeatures = false;
  StoreProvider? _store;

  static const _freeFeatures = [
    (Icons.volunteer_activism, 'Daily Gratitude'),
    (Icons.add_circle_outline, '2 Custom Habits'),
    (Icons.calendar_today, 'Weekly View'),
    (Icons.menu_book, 'Anchor Verses'),
  ];

  static const _proFeatures = [
    (Icons.all_inclusive_rounded, 'Unlimited Habits'),
    (Icons.bar_chart_rounded, 'Detailed Stats & Insights'),
    (Icons.notifications_rounded, 'Smart Reminders'),
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showContent = true);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showFeatures = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _store = context.read<StoreProvider>();
      _store!.addListener(_onStoreChanged);
    });
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    final store = _store;
    if (store == null || !mounted) return;
    // Fire onNext when premium is gained via either a new purchase or a restore.
    if (store.isPremium && !store.isPurchasing) {
      widget.onNext();
    }
  }

  String get _ctaLabel => switch (_selectedPlan) {
        _Plan.monthly => 'Subscribe Monthly',
        _Plan.annual => 'Start Free Trial',
        _Plan.lifetime => 'Buy Lifetime Access',
      };

  Future<void> _purchase(StoreProvider store) async {
    final product = switch (_selectedPlan) {
      _Plan.monthly => store.monthlyProduct,
      _Plan.annual => store.annualProduct,
      _Plan.lifetime => store.lifetimeProduct,
    };
    if (product != null) {
      await store.purchase(product);
      // Navigation is handled by _onStoreChanged when isPremium becomes true.
    } else {
      // Product unavailable (store unreachable) — let user continue on free.
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(children: [
            AnimatedOpacity(
              opacity: _showContent ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Column(children: [
                const Text(
                  'Go deeper with\nGraceWay Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: GraceWayColor.warmWhite,
                      height: 1.3),
                ),
                const SizedBox(height: 10),
                Text(
                  'Everything you need to build lasting habits rooted in faith.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ]),
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              opacity: _showFeatures ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: AnimatedSlide(
                offset: _showFeatures ? Offset.zero : const Offset(0, 0.15),
                duration: const Duration(milliseconds: 500),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _featureColumn(
                              label: 'FREE',
                              isGold: false,
                              features: _freeFeatures)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _featureColumn(
                              label: 'PRO',
                              isGold: true,
                              features: _proFeatures)),
                    ]),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _showFeatures ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: _planSelector(store),
            ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: store.isPurchasing ? null : () => _purchase(store),
              icon: store.isPurchasing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: GraceWayColor.charcoal))
                  : const Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text(_ctaLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: GraceWayColor.golden,
                foregroundColor: GraceWayColor.charcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(
              onPressed: store.isLoading ? null : () => store.restore(),
              child: Text('Restore',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5))),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: widget.onNext,
              child: Text('Continue with Free',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5))),
            ),
          ]),
          if (store.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(store.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: GraceWayColor.warmCoral)),
            ),
        ]),
      ),
    ]);
  }

  Widget _featureColumn({
    required String label,
    required bool isGold,
    required List<(IconData, String)> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGold
            ? GraceWayColor.golden.withValues(alpha: 0.06)
            : GraceWayColor.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGold
              ? GraceWayColor.golden.withValues(alpha: 0.2)
              : GraceWayColor.cardBorder,
          width: 0.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: isGold
                    ? GraceWayColor.golden
                    : Colors.white.withValues(alpha: 0.5),
              )),
          if (isGold) ...[
            const SizedBox(width: 6),
            const Icon(Icons.workspace_premium_rounded,
                size: 10, color: GraceWayColor.golden),
          ],
        ]),
        const SizedBox(height: 14),
        ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                SizedBox(
                  width: 18,
                  child: Icon(f.$1,
                      size: 13,
                      color: isGold
                          ? GraceWayColor.golden
                          : GraceWayColor.softGold.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(f.$2,
                      style: TextStyle(
                        fontSize: 12,
                        color: isGold
                            ? GraceWayColor.warmWhite
                            : Colors.white.withValues(alpha: 0.5),
                      )),
                ),
              ]),
            )),
      ]),
    );
  }

  Widget _planSelector(StoreProvider store) {
    final monthly = store.monthlyProduct;
    final annual = store.annualProduct;
    final lifetime = store.lifetimeProduct;

    if (monthly == null && annual == null && lifetime == null) {
      return Text('Loading plans\u2026',
          style:
              TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)));
    }

    return Column(children: [
      // Subscription row: monthly + annual side by side.
      if (monthly != null || annual != null)
        Row(children: [
          if (monthly != null) ...[
            Expanded(
                child: _planOption(
              title: 'Monthly',
              price: monthly.price,
              detail: 'per month',
              trialText: null,
              isSelected: _selectedPlan == _Plan.monthly,
              badge: null,
              onTap: () => setState(() => _selectedPlan = _Plan.monthly),
            )),
            const SizedBox(width: 12),
          ],
          if (annual != null)
            Expanded(
                child: _planOption(
              title: 'Yearly',
              price: annual.price,
              detail: '\$${(annual.rawPrice / 365).toStringAsFixed(2)}/day',
              trialText: '7-day free trial',
              isSelected: _selectedPlan == _Plan.annual,
              badge: store.monthlySavingsText,
              onTap: () => setState(() => _selectedPlan = _Plan.annual),
            )),
        ]),
      // Lifetime: full-width card below.
      if (lifetime != null) ...[
        if (monthly != null || annual != null) const SizedBox(height: 12),
        _planOption(
          title: 'Lifetime',
          price: lifetime.price,
          detail: 'one-time purchase · never expires',
          trialText: null,
          isSelected: _selectedPlan == _Plan.lifetime,
          badge: 'Best Deal',
          onTap: () => setState(() => _selectedPlan = _Plan.lifetime),
        ),
      ],
    ]);
  }

  Widget _planOption({
    required String title,
    required String price,
    required String detail,
    required String? trialText,
    required bool isSelected,
    required String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? GraceWayColor.golden.withValues(alpha: 0.08)
              : GraceWayColor.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? GraceWayColor.golden.withValues(alpha: 0.4)
                : GraceWayColor.cardBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: GraceWayColor.golden,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(badge,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: GraceWayColor.charcoal)),
            )
          else
            const SizedBox(height: 17),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isSelected
                    ? GraceWayColor.golden
                    : Colors.white.withValues(alpha: 0.5),
              )),
          const SizedBox(height: 4),
          Text(price,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? GraceWayColor.warmWhite
                    : Colors.white.withValues(alpha: 0.5),
              )),
          const SizedBox(height: 2),
          Text(detail,
              style:
                  TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          if (trialText != null) ...[
            const SizedBox(height: 4),
            Text(trialText,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? GraceWayColor.sage
                        : Colors.white.withValues(alpha: 0.3))),
          ],
        ]),
      ),
    );
  }
}
