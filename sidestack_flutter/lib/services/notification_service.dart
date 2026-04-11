import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
//
// Handles:
//   • Requesting notification permission on first launch
//   • Scheduling the daily "Log your SideStack activity" reminder
//     (message rotates by day-of-week so users don't see the same copy every day)
//   • Listening for foreground FCM messages and showing them locally
//   • Overdue invoice alerts (fires once per overdue invoice per session)
//
// Platform setup required (one-time, outside this file):
//   Android  → android/app/src/main/AndroidManifest.xml
//              Add inside <manifest>:
//                <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//              Add inside <application>:
//                <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id"
//                           android:value="sidestacks_channel"/>
//   iOS      → ios/Runner/AppDelegate.swift — UNUserNotificationCenter setup
//              Xcode → Runner → Signing & Capabilities → + Push Notifications
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'sidestacks_channel';
  static const _channelName = 'SideStacks Reminders';
  static const _channelDesc = 'Daily reminders to log your hustle activity';

  // Notification IDs — keep these stable so we don't double-fire
  static const _dailyReminderId = 0;
  static const _weeklySummaryId = 10;
  static const _overdueBaseId   = 100; // 100–199 reserved for overdue invoice alerts

  // ─── Rotating daily reminder messages ────────────────────────────────────
  //
  // Indexed 0–9. We pick by (weekday - 1) mod length so the message naturally
  // rotates through the week and users never see the same copy two days running.

  static const _dailyMessages = [
    // Mon (weekday=1 → index 0)
    'New week, fresh income 💰 Log your Monday hustle and own your numbers.',
    // Tue (weekday=2 → index 1)
    "Keep the momentum going. Have you logged today's activity? ⚡",
    // Wed (weekday=3 → index 2)
    'Mid-week check-in 📊 Log your income and see where you stand.',
    // Thu (weekday=4 → index 3)
    "The weekend's almost here. Any invoices to send before Friday? 📋",
    // Fri (weekday=5 → index 4)
    'TGIF! Close out the week strong. Log income before the weekend 🚀',
    // Sat (weekday=6 → index 5)
    "Side hustles don't take weekends off. Logged anything today? 🔥",
    // Sun (weekday=7 → index 6)
    'Sunday reset: check your numbers and plan the week ahead 📈',
    // Extras (used if list grows)
    'A transaction a day keeps the surprises away. Log yours now ✅',
    'The best freelancers know their numbers. Do you? 💡',
    'Your future self will thank you for logging income today 🙌',
  ];

  /// Returns the daily reminder body copy for today, rotating by weekday.
  static String _todayReminderBody() {
    final index = (DateTime.now().weekday - 1) % _dailyMessages.length;
    return _dailyMessages[index];
  }

  // ─── Initialise ───────────────────────────────────────────────────────────

  Future<void> init() async {
    // Request permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('NotificationService: permission denied');
      return;
    }

    // Set up local notifications channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Handle foreground FCM messages by showing a local notification
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Schedule daily reminder at 8 PM with today's rotating copy
    await scheduleDailyReminder(hour: 20, minute: 0);

    debugPrint('NotificationService: initialised');
  }

  // ─── Foreground FCM → local notification ──────────────────────────────────

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ─── Daily local reminder ─────────────────────────────────────────────────

  /// Schedules (or reschedules) the daily reminder.
  ///
  /// Each session we cancel the previous schedule and re-issue with today's
  /// rotating message copy. This means the message seen by the user rotates
  /// each day they open the app.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    // Cancel the previous daily reminder so the copy is always fresh
    await _localNotifications.cancel(_dailyReminderId);

    await _localNotifications.periodicallyShow(
      _dailyReminderId,
      '⚡ SideStacks',
      _todayReminderBody(),
      RepeatInterval.daily,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    debugPrint(
        'NotificationService: daily reminder rescheduled (${_todayReminderBody()})');
  }

  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Returns the FCM device token (useful for sending targeted pushes).
  Future<String?> getToken() => _messaging.getToken();

  // ─── Weekly summary notification ──────────────────────────────────────────

  /// Schedule a recurring weekly summary notification every week.
  /// Automatically fires once then repeats. Refreshed each app session with
  /// up-to-date weekly figures.
  Future<void> scheduleWeeklySummary({
    required double weeklyIncome,
    required double weeklyExpenses,
    required String symbol,
    String? bestStackName,
    double? weeklyHourlyRate,
  }) async {
    await _localNotifications.cancel(_weeklySummaryId);

    final profit = weeklyIncome - weeklyExpenses;

    // Build a rich, insight-led notification body
    final StringBuffer body = StringBuffer();
    if (weeklyIncome == 0) {
      body.write('No income logged this week. Add a transaction to stay on track 💡');
    } else if (profit >= 0) {
      body.write('${symbol}${profit.toStringAsFixed(0)} profit this week');
      if (bestStackName != null) body.write(' · $bestStackName led the way');
      if (weeklyHourlyRate != null) {
        body.write(' · ${symbol}${weeklyHourlyRate.toStringAsFixed(0)}/hr effective rate');
      }
      body.write(' 🚀');
    } else {
      body.write('Expenses up ${symbol}${profit.abs().toStringAsFixed(0)} vs income this week');
      if (bestStackName != null) body.write(' · $bestStackName was your top earner');
      body.write('. Worth a review 📉');
    }

    await _localNotifications.periodicallyShow(
      _weeklySummaryId,
      '📊 Weekly Hustle Recap',
      body.toString(),
      RepeatInterval.weekly,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    debugPrint('NotificationService: weekly digest scheduled — profit: $profit');
  }

  // ─── Stack health alert ───────────────────────────────────────────────────

  /// Show an immediate notification when a stack needs attention.
  Future<void> showStackHealthAlert({
    required String stackName,
    required String message,
  }) async {
    await _localNotifications.show(
      20,
      '⚠️ $stackName needs attention',
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ─── Dormant stack check (call on app resume) ─────────────────────────────

  /// Fires a health alert for the first stack that has been dormant > 14 days.
  Future<void> checkDormantStacks(
      List<Map<String, dynamic>> stackSummaries) async {
    // stackSummaries: [{name: String, daysSinceActivity: int}]
    for (final s in stackSummaries) {
      final days = (s['daysSinceActivity'] as num).toInt();
      if (days >= 14) {
        await showStackHealthAlert(
          stackName: s['name'] as String,
          message: 'No activity in $days days. Keep the momentum going!',
        );
        break; // one alert per session is enough
      }
    }
  }

  // ─── Expense spike alert ──────────────────────────────────────────────────

  /// Fires an alert if this month's expenses are >150% of the recent average.
  Future<void> checkExpenseSpike({
    required String stackName,
    required double thisMonthExpenses,
    required double avgExpenses,
    required String symbol,
  }) async {
    if (avgExpenses > 0 && thisMonthExpenses > avgExpenses * 1.5) {
      final pct = ((thisMonthExpenses / avgExpenses - 1) * 100).round();
      await showStackHealthAlert(
        stackName: stackName,
        message:
            'Expenses are $pct% above your recent average ($symbol${thisMonthExpenses.toStringAsFixed(0)}). Worth a review.',
      );
    }
  }

  // ─── Overdue invoice alerts ───────────────────────────────────────────────

  /// Shows a push notification for each newly-overdue invoice.
  ///
  /// [overdueInvoices] is a list of maps with keys:
  ///   - 'invoiceNumber' (String)
  ///   - 'clientName'    (String, may be empty)
  ///   - 'amount'        (double)
  ///   - 'symbol'        (String)
  ///   - 'daysOverdue'   (int)
  ///
  /// If there are 3 or more overdue invoices we show a single consolidated
  /// notification rather than one per invoice, to avoid spamming the user.
  Future<void> checkOverdueInvoices(
      List<Map<String, dynamic>> overdueInvoices) async {
    if (overdueInvoices.isEmpty) return;

    if (overdueInvoices.length == 1) {
      final inv = overdueInvoices.first;
      final client =
          (inv['clientName'] as String?)?.isNotEmpty == true ? inv['clientName'] as String : 'a client';
      final symbol = inv['symbol'] as String? ?? '';
      final amount = (inv['amount'] as num).toDouble();
      final days   = (inv['daysOverdue'] as num).toInt();
      final invNum = inv['invoiceNumber'] as String? ?? 'Invoice';

      await _localNotifications.show(
        _overdueBaseId,
        '🔴 Overdue: $invNum',
        '$symbol${amount.toStringAsFixed(0)} from $client is $days day${days == 1 ? '' : 's'} overdue. Chase it up!',
        _highPriorityDetails(),
      );
    } else if (overdueInvoices.length == 2) {
      // Two invoices — name them both
      final a = overdueInvoices[0];
      final b = overdueInvoices[1];
      final aNum = a['invoiceNumber'] as String? ?? 'Invoice';
      final bNum = b['invoiceNumber'] as String? ?? 'Invoice';
      final sym  = a['symbol'] as String? ?? '';
      final total = (a['amount'] as num).toDouble() +
          (b['amount'] as num).toDouble();

      await _localNotifications.show(
        _overdueBaseId,
        '🔴 2 Overdue Invoices',
        '$aNum and $bNum are overdue. $sym${total.toStringAsFixed(0)} outstanding. Time to follow up!',
        _highPriorityDetails(),
      );
    } else {
      // 3+ invoices — show aggregate total
      final sym   = overdueInvoices.first['symbol'] as String? ?? '';
      final total = overdueInvoices.fold<double>(
          0, (sum, inv) => sum + (inv['amount'] as num).toDouble());
      final count = overdueInvoices.length;

      await _localNotifications.show(
        _overdueBaseId,
        '🔴 $count Invoices Overdue',
        '$sym${total.toStringAsFixed(0)} outstanding across $count invoices. Review and follow up now.',
        _highPriorityDetails(),
      );
    }

    debugPrint(
        'NotificationService: overdue invoice alert shown (${overdueInvoices.length} invoices)');
  }

  NotificationDetails _highPriorityDetails() => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      );
}
