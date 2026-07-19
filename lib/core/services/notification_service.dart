import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/router/app_router.dart';
import 'package:smartscan/features/wallet/presentation/screens/card_entry_screen.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders: card expiry (30 days before, then on expiry) and
/// monthly credit-card bill due dates. Everything is scheduled on-device;
/// no push infrastructure.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'card_reminders',
    'Card reminders',
    channelDescription: 'Expiry alerts and bill due-date reminders',
    importance: Importance.defaultImportance,
  );

  static const _engageChannel = AndroidNotificationDetails(
    'engagement',
    'Reminders & tips',
    channelDescription: 'Gentle nudges to keep your wallet up to date',
    importance: Importance.defaultImportance,
  );

  /// Fixed id for the recurring "add your cards" nudge, kept separate from
  /// the incrementing expiry/bill ids so it can be managed on its own.
  static const int _engagementId = 900001;

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final localTz = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTz));
      } catch (_) {
        // Fall back to the bundled default (UTC) — reminders still fire,
        // just possibly a few hours off.
      }
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
      await scheduleEngagementReminder();
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Notification tapped — deep-link into the add-card flow.
  static void _onTap(NotificationResponse response) {
    if (response.payload == 'add_card') {
      try {
        appRouter.push('/card-entry', extra: const CardEntryArgs());
      } catch (e) {
        debugPrint('Notification tap navigation failed: $e');
      }
    }
  }

  /// Recurring once-a-day nudge to add/update cards. Interactive: tapping
  /// it deep-links into the app (payload 'add_card'). Kept to daily so it
  /// stays helpful rather than spammy (Play policy / retention friendly).
  static Future<void> scheduleEngagementReminder() async {
    if (!_ready) return;
    try {
      await _plugin.periodicallyShowWithDuration(
        _engagementId,
        'Add your cards to SmartScan',
        'Keep your bank, loyalty and visiting cards in one secure place. Tap to add a card.',
        const Duration(hours: 24),
        const NotificationDetails(android: _engageChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'add_card',
      );
    } catch (e) {
      debugPrint('Engagement reminder schedule failed: $e');
    }
  }

  /// Re-plans every reminder from the current vault. Called whenever
  /// cards change; safe to call before init (no-op).
  static Future<void> reschedule(List<WalletCard> cards,
      {bool isPro = false}) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      // cancelAll() also drops the recurring nudge — re-arm it (free + Pro).
      await scheduleEngagementReminder();
      // Bill & expiry reminders are a Pro feature.
      if (!isPro) return;
      var id = 0;
      final now = tz.TZDateTime.now(tz.local);

      for (final card in cards.where((c) => c.type.isPayment)) {
        final label = card.nickname.isNotEmpty ? card.nickname : card.title;

        // Expiry: last valid day is the end of the expiry month.
        if (card.hasExpiry) {
          final lastValid = tz.TZDateTime(
              tz.local, card.expiryYear!, card.expiryMonth! + 1, 0, 10);
          for (final (daysBefore, text) in [
            (30, 'expires next month — order a replacement'),
            (0, 'expires today'),
          ]) {
            final when = lastValid.subtract(Duration(days: daysBefore));
            if (when.isAfter(now)) {
              await _plugin.zonedSchedule(
                id++,
                'Card expiring',
                '$label (•••• ${card.last4}) $text.',
                when,
                const NotificationDetails(android: _channel),
                androidScheduleMode:
                    AndroidScheduleMode.inexactAllowWhileIdle,
              );
            }
          }
        }

        // Monthly bill due reminder, one day before the due day.
        final due = card.dueDay;
        if (due != null && due >= 1 && due <= 31) {
          final remindDay = due == 1 ? 28 : due - 1;
          var when = tz.TZDateTime(
              tz.local, now.year, now.month, remindDay.clamp(1, 28), 10);
          if (!when.isAfter(now)) {
            when = tz.TZDateTime(
                tz.local, now.year, now.month + 1, remindDay.clamp(1, 28), 10);
          }
          await _plugin.zonedSchedule(
            id++,
            'Bill due tomorrow',
            '$label bill is due on day $due. Pay to avoid late fees.',
            when,
            const NotificationDetails(android: _channel),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          );
        }
      }
    } catch (e) {
      debugPrint('Notification reschedule failed: $e');
    }
  }
}
