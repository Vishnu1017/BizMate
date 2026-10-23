import 'dart:io' show Platform;
import 'package:flutter_test/flutter_test.dart';
import 'package:bizmate/utils/upi_payment_helper.dart';

void main() {
  group('UpiPaymentHelper tests', () {
    const testUpi = 'merchant@okhdfcbank';
    const testName = 'John Doe & Sons';
    const testAmount = 1499.50;

    test('buildDirectUpiUri encodes parameters properly', () {
      final uri = UpiPaymentHelper.buildDirectUpiUri(
        upiId: testUpi,
        payeeName: testName,
        amount: testAmount,
        transactionNote: 'Invoice #1042',
      );

      expect(uri, startsWith('upi://pay?'));
      expect(uri, contains('pa=merchant@okhdfcbank'));
      expect(uri, contains('pn=John%20Doe%20%26%20Sons'));
      expect(uri, contains('am=1499.50'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tn=Invoice%20%231042'));
    });

    test('buildDirectUpiUri handles zero or null amount', () {
      final uriWithoutAmount = UpiPaymentHelper.buildDirectUpiUri(
        upiId: testUpi,
        payeeName: 'Jane Doe',
        amount: null,
      );
      expect(uriWithoutAmount, isNot(contains('&am=')));
      expect(uriWithoutAmount, contains('pa=$testUpi'));
      expect(uriWithoutAmount, contains('cu=INR'));

      final uriZeroAmount = UpiPaymentHelper.buildDirectUpiUri(
        upiId: testUpi,
        payeeName: 'Jane Doe',
        amount: 0.0,
      );
      expect(uriZeroAmount, isNot(contains('&am=')));
    });

    test('buildPhonePeLink generates valid phonepe URI', () {
      final link = UpiPaymentHelper.buildPhonePeLink(
        upiId: testUpi,
        payeeName: testName,
        amount: testAmount,
      );
      expect(link, startsWith('phonepe://pay?'));
      expect(link, contains('pa=$testUpi'));
      expect(link, contains('am=1499.50'));
    });

    test('buildBhimLink generates valid bhim URI', () {
      final link = UpiPaymentHelper.buildBhimLink(
        upiId: testUpi,
        payeeName: testName,
        amount: testAmount,
      );
      expect(link, startsWith('bhim://upi/pay?'));
      expect(link, contains('pa=$testUpi'));
    });

    test('buildGooglePayLink adapts to platform', () {
      final link = UpiPaymentHelper.buildGooglePayLink(
        upiId: testUpi,
        payeeName: testName,
        amount: testAmount,
      );
      if (Platform.isIOS) {
        expect(link, startsWith('gpay://upi/pay?'));
      } else {
        expect(link, startsWith('tez://upi/pay?'));
      }
      expect(link, contains('pa=$testUpi'));
    });

    test('buildPaytmLink adapts to platform', () {
      final link = UpiPaymentHelper.buildPaytmLink(
        upiId: testUpi,
        payeeName: testName,
        amount: testAmount,
      );
      if (Platform.isIOS) {
        expect(link, startsWith('paytm://upi/pay?'));
      } else {
        expect(link, startsWith('paytmmp://pay?'));
      }
      expect(link, contains('pa=$testUpi'));
    });

    test('buildHttpsGatewayLink generates browser-compatible gateway', () {
      final linkWithAmount = UpiPaymentHelper.buildHttpsGatewayLink(
        upiId: testUpi,
        payeeName: testName,
        amount: 250.00,
        transactionNote: 'Order 99',
      );
      expect(linkWithAmount, startsWith('https://upi.pe/$testUpi/250.00?'));
      expect(linkWithAmount, contains('pn=John%20Doe%20%26%20Sons'));
      expect(linkWithAmount, contains('cu=INR'));
      expect(linkWithAmount, contains('tn=Order%2099'));

      final linkWithoutAmount = UpiPaymentHelper.buildHttpsGatewayLink(
        upiId: testUpi,
        payeeName: testName,
      );
      expect(linkWithoutAmount, startsWith('https://upi.pe/?pa=$testUpi&'));
      expect(linkWithoutAmount, contains('pn=John%20Doe%20%26%20Sons'));
    });

    test('buildUniversalPaymentLink uses correct strategy', () {
      final link = UpiPaymentHelper.buildUniversalPaymentLink(
        upiId: testUpi,
        payeeName: testName,
        amount: testAmount,
      );
      if (Platform.isIOS) {
        expect(link, startsWith('upi://pay?'));
      } else {
        expect(link, startsWith('https://upi.pe/'));
      }
    });

    test('buildQrData returns standard NPCI string', () {
      final qr = UpiPaymentHelper.buildQrData(
        upiId: testUpi,
        payeeName: testName,
        amount: 500.0,
      );
      expect(qr, startsWith('upi://pay?'));
      expect(qr, contains('pa=$testUpi'));
      expect(qr, contains('am=500.00'));
    });
  });
}
