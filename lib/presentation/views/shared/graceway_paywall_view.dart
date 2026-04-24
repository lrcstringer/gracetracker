import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';

enum _Plan { monthly, annual, lifetime }

class GraceWayPaywallView extends StatefulWidget {
  final String? contextTitle;
  final String? contextMessage;

  const GraceWayPaywallView({super.key, this.contextTitle, this.contextMessage});

  @override
  State<GraceWayPaywallView> createState() => _GraceWayPaywallViewState();
}

class _GraceWayPaywallViewState extends State<GraceWayPaywallView> {
  _Plan _selectedPlan = _Plan.annual;
  bool _purchaseSuccess = false;
  StoreProvider? _store;

  static const _features = [
    (Icons.all_inclusive_rounded, 'Unlimited habits'),
    (Icons.shield_rounded, 'Recovery Path & partner support'),
    (Icons.bar_chart_rounded, 'Detailed analytics & insights'),
    (Icons.format_quote_rounded, 'Custom purpose statements'),
    (Icons.calendar_month_rounded, '52-week Year in GraceWay heatmap'),
    (Icons.notifications_rounded, 'Smart reminders'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _store = context.read<StoreProvider>();
      _store!.addListener(_onStoreChanged);
      // Handle the case where isPremium is already true on first frame.
      _onStoreChanged();
    });
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    if ((_store?.isPremium ?? false) && !_purchaseSuccess) {
      setState(() => _purchaseSuccess = true);
      // Capture Navigator before the async gap.
      final nav = Navigator.of(context);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) nav.pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(children: [
                _headerSection(),
                if (widget.contextTitle != null) ...[
                  const SizedBox(height: 20),
                  _contextSection(),
                ],
                const SizedBox(height: 24),
                _planCards(store),
                const SizedBox(height: 20),
                _featuresSection(),
              ]),
            ),
          ),
          _bottomSection(store),
        ]),
      ),
    );
  }

  Widget _headerSection() {
    return Column(children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            GraceWayColor.golden.withValues(alpha: 0.2),
            GraceWayColor.golden.withValues(alpha: 0.04),
          ]),
        ),
        child: const Icon(Icons.workspace_premium_rounded,
            size: 28, color: GraceWayColor.golden),
      ),
      const SizedBox(height: 10),
      const Text('GraceWay Pro',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: GraceWayColor.warmWhite)),
      const SizedBox(height: 6),
      Text('Go deeper in your walk with God.',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.6))),
    ]);
  }

  Widget _contextSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: GraceWayColor.golden.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Column(children: [
        Text(widget.contextTitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GraceWayColor.golden)),
        if (widget.contextMessage != null) ...[
          const SizedBox(height: 4),
          Text(widget.contextMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
        ],
      ]),
    );
  }

  Widget _planCards(StoreProvider store) {
    final monthly = store.monthlyProduct;
    final annual = store.annualProduct;
    final lifetime = store.lifetimeProduct;

    if (monthly == null && annual == null && lifetime == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Loading plans\u2026',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
      );
    }

    return Column(children: [
      // Subscription row.
      if (monthly != null || annual != null)
        Row(children: [
          if (monthly != null) ...[
            Expanded(
                child: _planCard(
              title: 'Monthly',
              price: monthly.price,
              subtitle: 'per month',
              selected: _selectedPlan == _Plan.monthly,
              badge: null,
              onTap: () => setState(() => _selectedPlan = _Plan.monthly),
            )),
            const SizedBox(width: 12),
          ],
          if (annual != null)
            Expanded(
                child: _planCard(
              title: 'Yearly',
              price: annual.price,
              subtitle: 'best value',
              selected: _selectedPlan == _Plan.annual,
              badge: store.monthlySavingsText,
              onTap: () => setState(() => _selectedPlan = _Plan.annual),
            )),
        ]),
      // Lifetime: full-width card below subscriptions.
      if (lifetime != null) ...[
        if (monthly != null || annual != null) const SizedBox(height: 12),
        _planCard(
          title: 'Lifetime',
          price: lifetime.price,
          subtitle: 'one-time · never expires',
          selected: _selectedPlan == _Plan.lifetime,
          badge: 'Best Deal',
          onTap: () => setState(() => _selectedPlan = _Plan.lifetime),
        ),
      ],
    ]);
  }

  Widget _planCard({
    required String title,
    required String price,
    required String subtitle,
    required bool selected,
    required String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
        decoration: BoxDecoration(
          color: selected
              ? GraceWayColor.golden.withValues(alpha: 0.08)
              : GraceWayColor.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? GraceWayColor.golden.withValues(alpha: 0.4)
                : GraceWayColor.cardBorder,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(children: [
          if (badge != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: GraceWayColor.golden,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: GraceWayColor.charcoal)),
            )
          else
            const SizedBox(height: 19),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? GraceWayColor.golden
                      : Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(price,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? GraceWayColor.warmWhite
                      : Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
        ]),
      ),
    );
  }

  Widget _featuresSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        children: _features
            .map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Icon(f.$1, size: 16, color: GraceWayColor.golden),
                    const SizedBox(width: 12),
                    Text(f.$2,
                        style: const TextStyle(
                            fontSize: 14, color: GraceWayColor.softGold)),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  Widget _bottomSection(StoreProvider store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(children: [
        if (_purchaseSuccess)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_rounded,
                color: GraceWayColor.sage, size: 18),
            const SizedBox(width: 8),
            const Text('Welcome to GraceWay Pro',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GraceWayColor.sage)),
          ])
        else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (store.isPurchasing || store.isLoading)
                  ? null
                  : () => _purchase(store),
              style: ElevatedButton.styleFrom(
                backgroundColor: GraceWayColor.golden,
                foregroundColor: GraceWayColor.charcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: store.isPurchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: GraceWayColor.charcoal))
                  : Text(_ctaLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(
              onPressed: store.isLoading ? null : () => store.restore(),
              child: Text('Restore Purchases',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5))),
            ),
            Text('\u00B7',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.3))),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Not now',
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
        ],
      ]),
    );
  }

  String get _ctaLabel => switch (_selectedPlan) {
        _Plan.monthly => 'Subscribe Monthly',
        _Plan.annual => 'Continue',
        _Plan.lifetime => 'Buy Lifetime Access',
      };

  Future<void> _purchase(StoreProvider store) async {
    final product = switch (_selectedPlan) {
      _Plan.monthly => store.monthlyProduct,
      _Plan.annual => store.annualProduct,
      _Plan.lifetime => store.lifetimeProduct,
    };
    if (product != null) await store.purchase(product);
  }
}
