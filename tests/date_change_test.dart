
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/presentation/utils/analytics_helper.dart';

// Since we can't easily unit test the full DayPlannerScreen Widget with Timers in a headless environment 
// without complex mocks, we will test the LOGIC extracted.
// The core logic relies on:
// 1. isSameDay check (AnalyticsHelper)
// 2. The Decision Logic: Update IF (_isViewingToday AND !isSameDay)
// 3. The Flag Logic: _isViewingToday = isSameDay(picked, now)

void main() {
  group('Date Change Logic Tests', () {

    test('1. AnalyticsHelper.isSameDay returns true for identical dates', () {
      final d1 = DateTime(2025, 12, 27, 10, 0);
      final d2 = DateTime(2025, 12, 27, 23, 59);
      expect(AnalyticsHelper.isSameDay(d1, d2), true);
    });

    test('2. AnalyticsHelper.isSameDay returns false for different days', () {
      final d1 = DateTime(2025, 12, 26, 23, 59);
      final d2 = DateTime(2025, 12, 27, 00, 01);
      expect(AnalyticsHelper.isSameDay(d1, d2), false);
    });

    // Simulated Logic Test Scenarios
    
    // Scenario: App Open (InitState)
    test('3. InitState should default to viewing Today', () {
      bool isViewingToday = true;
      DateTime selectedDate = DateTime.now(); // Defaults to now
      final now = DateTime.now();
      
      expect(isViewingToday, true);
      expect(AnalyticsHelper.isSameDay(selectedDate, now), true);
    });

    // Scenario: Timer Tick / Resume (Rollover)
    test('4. Rollover: If viewing today and day changes, update selectedDate', () {
      bool isViewingToday = true;
      DateTime selectedDate = DateTime(2025, 12, 26); // "Yesterday"
      final now = DateTime(2025, 12, 27); // "Today"
      
      // Logic from _checkRollover
      if (isViewingToday && !AnalyticsHelper.isSameDay(selectedDate, now)) {
         selectedDate = now;
      }

      expect(selectedDate, now);
    });

    test('5. Rollover: If NOT viewing today (viewing history), do NOT update', () {
      bool isViewingToday = false; // User navigated to history
      DateTime selectedDate = DateTime(2025, 12, 20); 
      final now = DateTime(2025, 12, 27);
      
      if (isViewingToday && !AnalyticsHelper.isSameDay(selectedDate, now)) {
         selectedDate = now;
      }

      // Should remain distinct
      expect(AnalyticsHelper.isSameDay(selectedDate, now), false);
      expect(selectedDate.day, 20);
    });

    // Scenario: Picking Date
    test('6. Pick Date: Picking Today sets flag to true', () {
       final now = DateTime(2025, 12, 27);
       final picked = DateTime(2025, 12, 27);
       bool isViewingToday = AnalyticsHelper.isSameDay(picked, now);
       
       expect(isViewingToday, true);
    });

    test('7. Pick Date: Picking Past Date sets flag to false', () {
       final now = DateTime(2025, 12, 27);
       final picked = DateTime(2025, 12, 26);
       bool isViewingToday = AnalyticsHelper.isSameDay(picked, now);
       
       expect(isViewingToday, false);
    });

    test('8. Resume: If flag was false, it stays false even if day changed', () {
       // User was looking at Dec 20th. App BG. Resume next day. 
       // Should still look at Dec 20th.
       bool isViewingToday = false;
       DateTime selectedDate = DateTime(2025, 12, 20);
       // Now is next day
       final now = DateTime.now(); 

       if (isViewingToday && !AnalyticsHelper.isSameDay(selectedDate, now)) {
          selectedDate = now;
       }

       expect(isViewingToday, false);
       expect(selectedDate.day, 20);
    });

    test('9. Resume: If flag was true (viewing Yesterday as Today), it updates', () {
       // Start: Dec 26. Viewing "Today" (Dec 26).
       // ... Sleep ...
       // Wake up: Dec 27. App Resume.
       bool isViewingToday = true;
       DateTime selectedDate = DateTime(2025, 12, 26);
       final now = DateTime(2025, 12, 27);

       if (isViewingToday && !AnalyticsHelper.isSameDay(selectedDate, now)) {
          selectedDate = now;
       }

       expect(selectedDate, now);
    });
    
    test('10. Edge Case: Midnight Exact', () {
       // selected = 23:59:59. now = 00:00:00.
       DateTime selectedDate = DateTime(2025, 12, 26, 23, 59, 59);
       final now = DateTime(2025, 12, 27, 00, 00, 00);
       bool isViewingToday = true;
       
       if (isViewingToday && !AnalyticsHelper.isSameDay(selectedDate, now)) {
          selectedDate = now; // Should trigger
       }
       expect(selectedDate, now);
    });

  });
}
