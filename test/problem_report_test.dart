import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/models/problem_report.dart';
import 'package:sd2/models/campus_location.dart';

void main() {
  group('ProblemReport Model Tests', () {
    test('Correctly parses Customer report JSON with enriched details', () {
      final json = {
        'id': 'rep-cust-001',
        'request_id': 'req-1234-abcd',
        'reporter_id': 'user-cust-01',
        'reporter_role': 'customer',
        'reported_user_id': 'user-run-01',
        'category': 'late_delivery',
        'description': 'The delivery took over an hour and food was cold.',
        'status': 'open',
        'admin_notes': '',
        'created_at': '2026-11-19T10:00:00Z',
        'reporter_name': 'Johann Bolabon',
        'reporter_email': 'bolabon@cit.edu',
        'reporter_student_id': '23-1630-581',
        'reported_user_name': 'Jerick Davidon',
        'reported_user_email': 'jerick@cit.edu',
        'reported_user_role': 'runner',
        'pickup_location': 'Main Canteen',
        'dropoff_location': 'GLE Building',
        'order_description': '2x Pork Siomai w/ rice',
        'order_status': 'completed',
        'order_estimated_price': '60.00',
        'order_delivery_fee': '25.00',
      };

      final report = ProblemReport.fromJson(json);

      expect(report.id, 'rep-cust-001');
      expect(report.isCustomerReport, isTrue);
      expect(report.isRunnerReport, isFalse);
      expect(report.hasOrder, isTrue);
      expect(report.hasReportedUser, isTrue);
      expect(report.categoryLabel, 'Late Delivery');
      expect(report.reporterName, 'Johann Bolabon');
      expect(report.reportedUserName, 'Jerick Davidon');
      expect(report.orderPickupLocation, 'Main Canteen');
      expect(report.orderDropoffLocation, 'GLE Building');
      expect(report.orderEstimatedPrice, 60.00);
      expect(report.orderDeliveryFee, 25.00);
    });

    test('Correctly parses Runner report JSON with customer dispute', () {
      final json = {
        'id': 'rep-run-002',
        'request_id': 'req-5678-efgh',
        'reporter_id': 'user-run-01',
        'reporter_role': 'runner',
        'reported_user_id': 'user-cust-01',
        'category': 'unresponsive_user',
        'description': 'Customer never showed up at Allied lobby after 15 mins.',
        'status': 'reviewing',
        'admin_notes': 'Sent warning email to customer',
        'created_at': '2026-11-19T10:30:00Z',
        'reporter_name': 'Jerick Davidon',
        'reporter_email': 'jerick@cit.edu',
        'reported_user_name': 'Johann Bolabon',
        'reported_user_role': 'customer',
        'pickup_location': 'Mini Canteen',
        'dropoff_location': 'Allied Building',
      };

      final report = ProblemReport.fromJson(json);

      expect(report.id, 'rep-run-002');
      expect(report.isCustomerReport, isFalse);
      expect(report.isRunnerReport, isTrue);
      expect(report.categoryLabel, 'Customer Unresponsive / No-show');
      expect(report.status, 'reviewing');
      expect(report.adminNotes, 'Sent warning email to customer');
    });

    test('Customer and Runner category lists contain required distinct options', () {
      expect(ProblemReport.customerCategories, contains('wrong_item'));
      expect(ProblemReport.customerCategories, contains('late_delivery'));
      expect(ProblemReport.customerCategories, contains('runner_behavior'));

      expect(ProblemReport.runnerCategories, contains('unresponsive_user'));
      expect(ProblemReport.runnerCategories, contains('customer_behavior'));
      expect(ProblemReport.runnerCategories, contains('wrong_location'));
      expect(ProblemReport.runnerCategories, contains('canteen_issue'));
    });
  });

  group('CampusLocation Canteen Image Helper Tests', () {
    test('Resolves correct asset paths for each official canteen', () {
      expect(
        CampusLocation.getCanteenImage('Main Canteen'),
        'assets/main_canteen.jpg',
      );
      expect(
        CampusLocation.getCanteenImage('Wildcats Cafe Main Canteen'),
        'assets/main_canteen.jpg',
      );
      expect(
        CampusLocation.getCanteenImage('Highschool Canteen'),
        'assets/highschool_canteen.jpg',
      );
      expect(
        CampusLocation.getCanteenImage('HS Canteen'),
        'assets/highschool_canteen.jpg',
      );
      expect(
        CampusLocation.getCanteenImage('Mini Canteen'),
        'assets/mini_canteen.jpg',
      );
    });
  });
}
