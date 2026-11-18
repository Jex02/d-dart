import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/models/cart_item.dart';
import 'package:sd2/models/campus_location.dart';
import 'package:sd2/models/delivery_order.dart';
import 'package:sd2/models/system_config.dart';
import 'package:sd2/services/cart_service.dart';

void main() {
  group('Campus Location & Distance Dataset Verification', () {
    test('Official Canteen count is exactly 3', () {
      expect(CampusLocation.officialCanteens.length, 3);
      expect(
        CampusLocation.officialCanteens,
        containsAll([
          'Main Canteen',
          'Highschool Canteen',
          'Mini Canteen',
        ]),
      );
      expect(CampusLocation.defaultPickups.length, 3);
    });

    test(
        'Official Destination count is exactly 11 and respects campus boundary rules',
        () {
      expect(CampusLocation.officialDestinations.length, 11);
      expect(CampusLocation.defaultDropoffs.length, 11);

      // Verify specific building segregation rules per SDD & campus layout
      expect(CampusLocation.officialDestinations, contains('GLE'));
      expect(CampusLocation.officialDestinations, contains('G-LECROOM'));
      expect('GLE' != 'G-LECROOM', isTrue);

      expect(CampusLocation.officialDestinations, contains('NGE'));
      expect(CampusLocation.officialDestinations, contains('Allied'));
      expect('NGE' != 'Allied', isTrue);

      // Verify prohibited and merged destinations are absent
      expect(
          CampusLocation.officialDestinations, isNot(contains('College Library')));
      expect(CampusLocation.officialDestinations,
          isNot(contains('University Library')));
      expect(CampusLocation.officialDestinations,
          isNot(contains('Engineering Building')));
    });

    test('Verifies all 6 prompt sample cases', () {
      // 1. Mini Canteen -> Allied = 50.19 m
      expect(
        CampusLocation.getDistanceMeters('Mini Canteen', 'Allied'),
        50.19,
      );

      // 2. Main Canteen -> Covered Courts = 38.26 m
      expect(
        CampusLocation.getDistanceMeters('Main Canteen', 'Covered Courts'),
        38.26,
      );

      // 3. High School Canteen -> Gymnasium = 38.37 m
      expect(
        CampusLocation.getDistanceMeters('High School Canteen', 'Gymnasium'),
        38.37,
      );

      // 4. Mini Canteen -> Backgate Annex = 240.53 m
      expect(
        CampusLocation.getDistanceMeters('Mini Canteen', 'Backgate Annex'),
        240.53,
      );

      // 5. Main Canteen -> NGE = 206.28 m
      expect(
        CampusLocation.getDistanceMeters('Main Canteen', 'NGE'),
        206.28,
      );

      // 6. High School Canteen -> NGE = 267.64 m
      expect(
        CampusLocation.getDistanceMeters('High School Canteen', 'NGE'),
        267.64,
      );
    });

    test('Verifies ALL 33 official combinations against ground-truth distance matrix', () {
      final expectedTable = <String, Map<String, double>>{
        'Backgate Annex': {
          'Mini Canteen': 240.53,
          'Main Canteen': 141.30,
          'High School Canteen': 61.66,
        },
        'GLE': {
          'Mini Canteen': 164.55,
          'Main Canteen': 104.26,
          'High School Canteen': 187.23,
        },
        'G-LECROOM': {
          'Mini Canteen': 129.87,
          'Main Canteen': 94.43,
          'High School Canteen': 109.98,
        },
        'NGE': {
          'Mini Canteen': 98.15,
          'Main Canteen': 206.28,
          'High School Canteen': 267.64,
        },
        'Allied': {
          'Mini Canteen': 50.19,
          'Main Canteen': 183.27,
          'High School Canteen': 198.63,
        },
        'SAL': {
          'Mini Canteen': 160.91,
          'Main Canteen': 96.03,
          'High School Canteen': 79.73,
        },
        'ACAD': {
          'Mini Canteen': 194.27,
          'Main Canteen': 68.04,
          'High School Canteen': 150.93,
        },
        'RTL': {
          'Mini Canteen': 69.61,
          'Main Canteen': 153.93,
          'High School Canteen': 200.92,
        },
        'Physics Lab': {
          'Mini Canteen': 126.04,
          'Main Canteen': 88.39,
          'High School Canteen': 125.51,
        },
        'Gymnasium': {
          'Mini Canteen': 239.23,
          'Main Canteen': 110.17,
          'High School Canteen': 38.37,
        },
        'Covered Courts': {
          'Mini Canteen': 190.01,
          'Main Canteen': 38.26,
          'High School Canteen': 46.48,
        },
      };

      int verifiedCombinations = 0;
      for (final destEntry in expectedTable.entries) {
        final dest = destEntry.key;
        for (final canteenEntry in destEntry.value.entries) {
          final canteen = canteenEntry.key;
          final expectedMeters = canteenEntry.value;

          final actual = CampusLocation.getDistanceMeters(canteen, dest);
          expect(
            actual,
            equals(expectedMeters),
            reason: 'Mismatch for $canteen -> $dest',
          );
          verifiedCombinations++;
        }
      }

      expect(verifiedCombinations, 33);
    });

    test('Selecting different canteens changes the retrieved distance correctly', () {
      const dest = 'Covered Courts';
      final distMini = CampusLocation.getDistanceMeters('Mini Canteen', dest);
      final distMain = CampusLocation.getDistanceMeters('Main Canteen', dest);
      final distHS = CampusLocation.getDistanceMeters('High School Canteen', dest);

      expect(distMini, 190.01);
      expect(distMain, 38.26);
      expect(distHS, 46.48);

      expect(distMini != distMain, isTrue);
      expect(distMain != distHS, isTrue);
      expect(distMini != distHS, isTrue);
    });

    test('Normalizes legacy aliases for seamless backward compatibility', () {
      expect(CampusLocation.getDistanceMeters('Main Canteen', 'ALLIED Building'), 183.27);
      expect(CampusLocation.getDistanceMeters('Mini Canteen', 'GLE Building'), 164.55);
      expect(CampusLocation.getDistanceMeters('College Canteen', 'ACAD'), 68.04);
    });
  });

  group('Part 6: Approved Option A Distance-Based Delivery Pricing Tests', () {
    const config = SystemConfig(
      deliveryFeeShort: 20.0,
      deliveryFeeMedium: 25.0,
      deliveryFeeLong: 30.0,
      deliveryDistanceShortMax: 100.0,
      deliveryDistanceMediumMax: 200.0,
    );

    test('2. 50.19 m = ₱20 (Mini Canteen -> Allied)', () {
      final fee = CampusLocation.calculateFeeForDistance(50.19, config: config);
      expect(fee, 20.0);
    });

    test('3. Exact boundary condition: 100.00 m = ₱20', () {
      final fee = CampusLocation.calculateFeeForDistance(100.00, config: config);
      expect(fee, 20.0);
    });

    test('4. Exact boundary condition: 100.01 m = ₱25', () {
      final fee = CampusLocation.calculateFeeForDistance(100.01, config: config);
      expect(fee, 25.0);
    });

    test('5. 153.93 m = ₱25 (Main Canteen -> RTL)', () {
      final fee = CampusLocation.calculateFeeForDistance(153.93, config: config);
      expect(fee, 25.0);
    });

    test('6. Exact boundary condition: 200.00 m = ₱25', () {
      final fee = CampusLocation.calculateFeeForDistance(200.00, config: config);
      expect(fee, 25.0);
    });

    test('7. Exact boundary condition: 200.01 m = ₱30', () {
      final fee = CampusLocation.calculateFeeForDistance(200.01, config: config);
      expect(fee, 30.0);
    });

    test('8. 240.53 m = ₱30 (Mini Canteen -> Backgate Annex)', () {
      final fee = CampusLocation.calculateFeeForDistance(240.53, config: config);
      expect(fee, 30.0);
    });

    test('11. Missing distance handling: returns null and prevents default fee', () {
      // Non-existent combination returns null
      final feeInvalid = CampusLocation.calculateDeliveryFee(
        canteen: 'Unknown Canteen',
        destination: 'Unknown Building',
        config: config,
      );
      expect(feeInvalid, isNull);

      final feeMissingDest = CampusLocation.calculateDeliveryFee(
        canteen: 'Main Canteen',
        destination: 'Imaginary Hall',
        config: config,
      );
      expect(feeMissingDest, isNull);
    });

    test('9 & 10. Multiple canteens in one cart and repeated items from same canteen', () {
      final cart = CartService.instance;
      cart.clearCart();

      const itemMini1 = CanteenMenuItem(
        id: 't-mini-1',
        canteen: 'Mini Canteen',
        category: 'Food',
        name: 'Snack A',
        price: 30.0,
        unitDescription: '1 pack',
      );
      const itemMini2 = CanteenMenuItem(
        id: 't-mini-2',
        canteen: 'Mini Canteen',
        category: 'Beverages',
        name: 'Juice A',
        price: 20.0,
        unitDescription: '1 cup',
      );
      const itemMain1 = CanteenMenuItem(
        id: 't-main-1',
        canteen: 'Main Canteen',
        category: 'Food',
        name: 'Lunch Meal',
        price: 75.0,
        unitDescription: '1 plate',
      );

      // Add 2 items from Mini Canteen (repeated items from same canteen)
      cart.addItem(itemMini1, quantity: 2);
      cart.addItem(itemMini2, quantity: 1);

      // Add 1 item from Main Canteen
      cart.addItem(itemMain1, quantity: 1);

      expect(cart.activeCanteens.length, 2);
      expect(cart.activeCanteens, containsAll(['Mini Canteen', 'Main Canteen']));

      // Destination: 'Allied'
      // Mini Canteen -> Allied: 50.19 m (<= 100 m) -> ₱20
      // Main Canteen -> Allied: 183.27 m (100.01 to 200 m) -> ₱25
      // Combined fee = ₱20 + ₱25 = ₱45
      // Notice: Mini Canteen repeated items (3 total items) do NOT duplicate the Mini Canteen fee
      final feeAllied = cart.calculateDeliveryFeeTo('Allied', config: config);
      expect(feeAllied, 45.0);

      // Destination: 'NGE'
      // Mini Canteen -> NGE: 98.15 m (<= 100 m) -> ₱20
      // Main Canteen -> NGE: 206.28 m (> 200 m) -> ₱30
      // Combined fee = ₱20 + ₱30 = ₱50
      final feeNge = cart.calculateDeliveryFeeTo('NGE', config: config);
      expect(feeNge, 50.0);

      // Destination with missing distance should return null
      final feeInvalid = cart.calculateDeliveryFeeTo('NonExistent', config: config);
      expect(feeInvalid, isNull);

      cart.clearCart();
    });

    test('12 & 13. Pabili pricing updates & Checkout total consistency', () {
      // Order 1: Mini Canteen -> Allied (50.19 m) -> ₱20 fee
      final fee1 = CampusLocation.calculateDeliveryFee(
        canteen: 'Mini Canteen',
        destination: 'Allied',
        config: config,
      );
      expect(fee1, 20.0);
      const itemCost1 = 85.0;
      final total1 = itemCost1 + fee1!;
      expect(total1, 105.0);

      // Order 2: Main Canteen -> NGE (206.28 m) -> ₱30 fee
      final fee2 = CampusLocation.calculateDeliveryFee(
        canteen: 'Main Canteen',
        destination: 'NGE',
        config: config,
      );
      expect(fee2, 30.0);
      const itemCost2 = 120.0;
      final total2 = itemCost2 + fee2!;
      expect(total2, 150.0);
    });

    test('14. Historical order compatibility: plain strings, unmapped destinations do not crash', () {
      // Historical order JSON from Supabase
      final historicalJson = {
        'id': 'hist-001',
        'pickup_location': 'College Canteen',
        'dropoff_location': 'GLE Building',
        'description': '2x Siomai Rice',
        'estimated_price': 70.0,
        'delivery_fee': 20.0,
        'status': 'completed',
        'verification_code': '1234',
      };

      final order = DeliveryOrder.fromJson(historicalJson);
      expect(order.pickupLocation, 'College Canteen');
      expect(order.dropoffLocation, 'GLE Building');
      expect(order.deliveryFee, 20.0);
      expect(order.totalAmount, 90.0);

      // Distance lookup normalizes GLE Building -> GLE (164.55 m for Mini Canteen, etc.)
      final dist = CampusLocation.getDistanceMeters(order.pickupLocation, order.dropoffLocation);
      // 'College Canteen' has canonical alias to 'Main Canteen', 'GLE Building' to 'GLE': 104.26 m
      expect(dist, 104.26);

      // Unmapped legacy destination safely returns null without exception
      final unmappedDist = CampusLocation.getDistanceMeters('Old Place', 'Far Away');
      expect(unmappedDist, isNull);
    });
  });
}
