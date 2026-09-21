import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:shop/core/config/payment_config.dart';

class PaymentVerificationService {
  Future<PaymentVerificationResult> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String customerEmail,
    required String customerName,
    required int amountInPaise,
    required String currency,
    required List<PaymentVerificationItem> items,
  }) async {
    if (razorpayPaymentVerificationUrl.isEmpty) {
      throw StateError(
        'Configure a backend verification endpoint before continuing checkout.',
      );
    }

    final uri = Uri.parse(razorpayPaymentVerificationUrl);
    final payload = <String, dynamic>{
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'amount': amountInPaise,
      'currency': currency,
      'items': items.map((item) => item.toJson()).toList(),
    };

    try {
      if (kDebugMode) {
        debugPrint('[payment-verification] POST $uri');
      }

      final response = await http
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 40));

      final statusCode = response.statusCode;
      final responseBody = response.body.trim();

      if (kDebugMode) {
        debugPrint(
          '[payment-verification] status=$statusCode',
        );
      }

      final isGatewayError =
          statusCode == 502 || statusCode == 503 || statusCode == 504;
      final isHtml = responseBody.startsWith('<') ||
          responseBody.toLowerCase().contains('<!doctype html') ||
          responseBody.toLowerCase().contains('<html');

      if (isGatewayError || (isHtml && statusCode >= 500)) {
        throw PaymentVerificationException(
          message:
              'Payment server is currently busy or starting up (Status $statusCode). Your payment was received; please allow a moment for processing.',
          url: uri.toString(),
          statusCode: statusCode,
          responseBody: responseBody,
          requestPayload: payload,
        );
      }

      final decodedBody = _decodeResponseBody(responseBody);

      if (statusCode < 200 || statusCode >= 300) {
        final backendMessage = _extractBackendMessage(decodedBody);
        throw PaymentVerificationException(
          message:
              backendMessage?.trim().isNotEmpty == true
              ? backendMessage!
              : 'Payment verification failed with status $statusCode.',
          url: uri.toString(),
          statusCode: statusCode,
          responseBody: responseBody,
          requestPayload: payload,
        );
      }

      if (decodedBody is! Map<String, dynamic>) {
        throw PaymentVerificationException(
          message: 'Backend returned an unexpected verification response format.',
          url: uri.toString(),
          statusCode: statusCode,
          responseBody: responseBody,
          requestPayload: payload,
        );
      }

      final success = decodedBody['success'] as bool? ?? false;
      if (!success) {
        throw PaymentVerificationException(
          message:
              _extractBackendMessage(decodedBody) ??
              'Payment verification failed. Please try again.',
          url: uri.toString(),
          statusCode: statusCode,
          responseBody: responseBody,
          requestPayload: payload,
        );
      }

      return PaymentVerificationResult(
        message:
            decodedBody['message'] as String? ??
            'Payment verified and order created',
        orderId: decodedBody['orderId'] as String?,
        order: decodedBody['order'] as Map<String, dynamic>?,
      );
    } on SocketException {
      throw PaymentVerificationException(
        message:
            'Unable to reach the payment confirmation backend. Check your connection.',
        url: uri.toString(),
        requestPayload: payload,
      );
    } on TimeoutException {
      throw PaymentVerificationException(
        message: 'The backend took too long to verify the payment. Your payment may have already succeeded.',
        url: uri.toString(),
        requestPayload: payload,
      );
    } on FormatException {
      throw PaymentVerificationException(
        message: 'The payment server returned an unexpected response format.',
        url: uri.toString(),
        requestPayload: payload,
      );
    }
  }

  String? _extractBackendMessage(Object? decodedBody) {
    if (decodedBody is Map<String, dynamic>) {
      return decodedBody['error'] as String? ??
          decodedBody['message'] as String?;
    }
    return null;
  }

  Object? _decodeResponseBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    return jsonDecode(body);
  }
}

class PaymentVerificationItem {
  const PaymentVerificationItem({
    required this.name,
    required this.quantity,
    required this.priceInPaise,
  });

  final String name;
  final int quantity;
  final int priceInPaise;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'quantity': quantity,
      'price': priceInPaise,
    };
  }
}

class PaymentVerificationResult {
  const PaymentVerificationResult({
    required this.message,
    this.orderId,
    this.order,
  });

  final String message;
  final String? orderId;
  final Map<String, dynamic>? order;
}

class PaymentVerificationException implements Exception {
  const PaymentVerificationException({
    required this.message,
    required this.url,
    this.statusCode,
    this.responseBody,
    this.requestPayload,
  });

  final String message;
  final String url;
  final int? statusCode;
  final String? responseBody;
  final Map<String, dynamic>? requestPayload;

  String toDisplayMessage() {
    final buffer = StringBuffer(message);
    buffer.write('\nURL: $url');
    if (statusCode != null) {
      buffer.write('\nStatus: $statusCode');
    }
    if (responseBody != null && responseBody!.trim().isNotEmpty) {
      buffer.write('\nResponse: ${_truncate(responseBody!.trim())}');
    }
    return buffer.toString();
  }

  @override
  String toString() => toDisplayMessage();

  String _truncate(String value) {
    const maxLength = 300;
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }
}
