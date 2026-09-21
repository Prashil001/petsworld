import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/cart_pricing_summary_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/models/product_option_model.dart';

void main() {
  group('CartItemModel Stock Tests', () {
    test('Calculates availableStock correctly for base product without options', () {
      const product = ProductModel(
        id: 'p1',
        name: 'Dog Food',
        price: 500,
        imageUrl: '',
        stockQuantity: 10,
      );

      const item = CartItemModel(
        product: product,
        selectedOptionId: '',
        selectedOptionLabel: '',
        unitPrice: 500,
        quantity: 2,
      );

      expect(item.availableStock, equals(10));
      expect(item.isOutOfStock, isFalse);
      expect(item.hasExceededStock, isFalse);
    });

    test('Returns 0 availableStock for inactive product', () {
      const product = ProductModel(
        id: 'p1_inactive',
        name: 'Hidden Food',
        price: 500,
        imageUrl: '',
        stockQuantity: 10,
        isActive: false,
      );

      const item = CartItemModel(
        product: product,
        selectedOptionId: '',
        selectedOptionLabel: '',
        unitPrice: 500,
        quantity: 1,
      );

      expect(item.availableStock, equals(0));
      expect(item.isOutOfStock, isTrue);
      expect(item.hasExceededStock, isTrue);
    });

    test('Calculates availableStock correctly for pack option', () {
      const product = ProductModel(
        id: 'p2',
        name: 'Cat Litter',
        price: 300,
        imageUrl: '',
        stockQuantity: 20,
        packOptions: [
          ProductOptionModel(
            id: 'opt1',
            label: '5kg',
            price: 300,
            stockQuantity: 4,
          ),
          ProductOptionModel(
            id: 'opt2',
            label: '10kg',
            price: 550,
            stockQuantity: 0,
          ),
        ],
      );

      const inStockItem = CartItemModel(
        product: product,
        selectedOptionId: 'opt1',
        selectedOptionLabel: '5kg',
        unitPrice: 300,
        quantity: 2,
      );

      const outOfStockItem = CartItemModel(
        product: product,
        selectedOptionId: 'opt2',
        selectedOptionLabel: '10kg',
        unitPrice: 550,
        quantity: 1,
      );

      expect(inStockItem.availableStock, equals(4));
      expect(inStockItem.isOutOfStock, isFalse);
      expect(inStockItem.hasExceededStock, isFalse);

      expect(outOfStockItem.availableStock, equals(0));
      expect(outOfStockItem.isOutOfStock, isTrue);
      expect(outOfStockItem.hasExceededStock, isTrue);
    });

    test('Identifies when item quantity exceeds available stock', () {
      const product = ProductModel(
        id: 'p3',
        name: 'Pet Shampoo',
        price: 250,
        imageUrl: '',
        stockQuantity: 3,
      );

      const item = CartItemModel(
        product: product,
        selectedOptionId: '',
        selectedOptionLabel: '',
        unitPrice: 250,
        quantity: 5,
      );

      expect(item.availableStock, equals(3));
      expect(item.isOutOfStock, isFalse);
      expect(item.hasExceededStock, isTrue);
    });
  });

  group('CartPricingSummaryModel Tests', () {
    test('Calculates total, discounts, and free delivery qualification correctly', () {
      const pricing = CartPricingSummaryModel(
        subtotal: 1000,
        originalSubtotal: 1200,
        productDiscount: 200,
        couponDiscount: 100,
        deliveryCharge: 0,
        total: 900,
        freeDeliveryThreshold: 500,
      );

      expect(pricing.total, equals(900));
      expect(pricing.qualifiesForFreeDelivery, isTrue);
      expect(pricing.amountLeftForFreeDelivery, equals(0));
      expect(pricing.totalDiscount, equals(300));
    });

    test('Zero total order with 100% discount', () {
      const pricing = CartPricingSummaryModel(
        subtotal: 500,
        originalSubtotal: 500,
        productDiscount: 0,
        couponDiscount: 500,
        deliveryCharge: 0,
        total: 0,
        freeDeliveryThreshold: 500,
      );

      expect(pricing.total, equals(0));
    });
  });
}
