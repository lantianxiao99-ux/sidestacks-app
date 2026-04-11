import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RevenueCat configuration
//
// 1. Create an account at https://app.revenuecat.com
// 2. Create a new project and add both iOS and Android apps
// 3. Paste each platform's public API key below (Project → API Keys)
// 4. In the RC dashboard create:
//    • One Entitlement with ID  "premium"
//    • One Product (monthly subscription) attached to that entitlement
//    • One Offering (default) containing that product as the Monthly package
// ─────────────────────────────────────────────────────────────────────────────

const _kAndroidApiKey = 'goog_ARPTbIyMosKndzYjgnIfobNOyfc';
const _kIosApiKey     = 'YOUR_REVENUECAT_IOS_API_KEY';

/// The entitlement ID configured in the RevenueCat dashboard.
const kRcEntitlement = 'SideStacks Pro';

class PurchaseService {
  PurchaseService._();
  static final instance = PurchaseService._();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Call once in main() before runApp().
  Future<void> configure() async {
    final apiKey = Platform.isIOS ? _kIosApiKey : _kAndroidApiKey;
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Call when a user signs in so RC links purchases to their account.
  Future<void> logIn(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
  }

  /// Call on sign-out so RC reverts to anonymous mode.
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  // ── Entitlement check ──────────────────────────────────────────────────────

  /// Returns true if the user currently has an active "premium" entitlement.
  Future<bool> get isPremium async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(kRcEntitlement);
    } catch (_) {
      return false;
    }
  }

  // ── Offerings ─────────────────────────────────────────────────────────────

  /// Returns the monthly [Package] from the default offering, or null if
  /// unavailable (e.g. no network, products not configured in RC).
  Future<Package?> getMonthlyPackage() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.monthly;
    } catch (_) {
      return null;
    }
  }

  /// Returns the annual [Package] from the default offering, or null if
  /// unavailable. Configure in RevenueCat as the "Annual" package type.
  Future<Package?> getAnnualPackage() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.annual;
    } catch (_) {
      return null;
    }
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  /// Initiates a purchase for the given [package].
  ///
  /// Returns the updated [CustomerInfo] on success.
  /// Throws [PlatformException] on failure; check [PurchasesErrorCode] to
  /// distinguish a user cancellation from a real error.
  Future<CustomerInfo> purchase(Package package) {
    return Purchases.purchasePackage(package);
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  /// Restores prior purchases. Returns true if the premium entitlement is
  /// now active.
  Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(kRcEntitlement);
    } catch (_) {
      return false;
    }
  }
}
