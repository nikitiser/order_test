import 'package:order/order.dart';
import 'package:test/test.dart';
import 'package:decimal/decimal.dart';

void main() {
  group('Order recalculation tests', () {
    test('Calculate gross sale without discounts', () {
      Order order = Order(
        items: [
          OrderItem(quantity: Decimal.parse('1.0'), price: Money.parse('30.00')),
          OrderItem(quantity: Decimal.parse('2.0'), price: Money.parse('50.00')),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['grossSale'].value, Decimal.parse('130.00'));
    });

    test('Calculate gross sale with item discounts', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('1.0'),
            price: Money.parse('30.00'),
            discount: Discount(isPercent: true, value: Decimal.parse('0.1')),
          ),
          OrderItem(
            quantity: Decimal.parse('2.0'),
            price: Money.parse('50.00'),
            discount: Discount(isPercent: false, value: Decimal.parse('5.00')),
          ),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['grossSale'].value, Decimal.parse('130.00'));
      expect(result['totalAfterItemDiscounts'].value, Decimal.parse('122.00'));
    });

    test('Order discount calculation and distribution', () {
      Order order = Order(
        items: [
          OrderItem(quantity: Decimal.parse('1.0'), price: Money.parse('30.00')),
          OrderItem(quantity: Decimal.parse('2.0'), price: Money.parse('50.00')),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('10.00')),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['totalOrderDiscount'].value, Decimal.parse('10.00'));
      expect(result['netSale'].value, Decimal.parse('120.00'));
    });

    test('Calculate taxes with different rates', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('1.0'),
            price: Money.parse('100.00'),
            taxes: [
              Tax(name: 'GST', percent: Decimal.parse('0.05')),
              Tax(name: 'HST', percent: Decimal.parse('0.1')),
            ],
          ),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['totalTaxesByType']['GST']!.value, Decimal.parse('5.00'));
      expect(result['totalTaxesByType']['HST']!.value, Decimal.parse('10.00'));
      expect(result['finalAmount'].value, Decimal.parse('115.00'));
    });

    test('No negative values in any calculation', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('1.0'),
            price: Money.parse('30.00'),
            discount: Discount(isPercent: true, value: Decimal.parse('0.1')),
            taxes: [Tax(name: 'GST', percent: Decimal.parse('0.05'))],
          ),
          OrderItem(
            quantity: Decimal.parse('1.0'),
            price: Money.parse('70.00'),
            taxes: [Tax(name: 'HST', percent: Decimal.parse('0.1'))],
          ),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('5.00')),
        ],
      );

      var result = order.recalculateOrder();

      // Проверка на отсутствие отрицательных значений
      expect(result['grossSale'].value >= Decimal.zero, isTrue);
      expect(result['totalAfterItemDiscounts'].value >= Decimal.zero, isTrue);
      expect(result['totalOrderDiscount'].value >= Decimal.zero, isTrue);
      expect(result['netSale'].value >= Decimal.zero, isTrue);
      expect(result['finalAmount'].value >= Decimal.zero, isTrue);
      for (var tax in result['totalTaxesByType'].values) {
        expect(tax.value >= Decimal.zero, isTrue);
      }
    });

    test('Calculate with zero quantity', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.zero,
            price: Money.parse('100.00'),
            discount: Discount(isPercent: true, value: Decimal.parse('0.1')),
            taxes: [
              Tax(name: 'GST', percent: Decimal.parse('0.05')),
              Tax(name: 'HST', percent: Decimal.parse('0.1')),
            ],
          ),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('5.00')),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['grossSale'].value, Decimal.zero);
      expect(result['totalAfterItemDiscounts'].value, Decimal.zero);
      expect(result['netSale'].value, Decimal.zero);
      expect(result['finalAmount'].value, Decimal.zero);
    });

    test('Calculate with zero price', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('1.0'),
            price: Money.parse('0.00'),
            discount: Discount(isPercent: true, value: Decimal.parse('0.1')),
            taxes: [
              Tax(name: 'GST', percent: Decimal.parse('0.05')),
              Tax(name: 'HST', percent: Decimal.parse('0.1')),
            ],
          ),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('5.00')),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['grossSale'].value, Decimal.zero);
      expect(result['totalAfterItemDiscounts'].value, Decimal.zero);
      expect(result['netSale'].value, Decimal.zero);
      expect(result['finalAmount'].value, Decimal.zero);
    });

    test('Calculate with maximum discount', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('1.0'),
            price: Money.parse('100.00'),
            discount: Discount(isPercent: true, value: Decimal.parse('1.0')),
          ),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['totalAfterItemDiscounts'].value, Decimal.zero);
      expect(result['netSale'].value, Decimal.zero);
      expect(result['finalAmount'].value, Decimal.zero);
    });

    test('Distribute order discount accurately', () {
      Order order = Order(
        items: [
          OrderItem(quantity: Decimal.parse('1.0'), price: Money.parse('30.00')),
          OrderItem(quantity: Decimal.parse('1.0'), price: Money.parse('70.00')),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('10.00')),
        ],
      );

      var result = order.recalculateOrder();
      var itemsDetails = result['itemsDetails'];

      // Проверяем распределение скидки по элементам
      Decimal distributedDiscount = Decimal.zero;
      for (var itemDetail in itemsDetails) {
        distributedDiscount += itemDetail['orderDiscountAmount'].value;
      }

      expect(distributedDiscount, result['totalOrderDiscount'].value);
    });

    test('Check rounding to two decimal places', () {
      Order order = Order(
        items: [
          OrderItem(quantity: Decimal.parse('1.0'), price: Money.parse('99.999')),
          OrderItem(quantity: Decimal.parse('1.0'), price: Money.parse('50.005')),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('0.01')),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['grossSale'].toString(), '150.01');
      expect(result['finalAmount'].toString(), result['finalAmount'].value.toStringAsFixed(2));
    });

    test('Test minimal values for quantities and prices', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('0.01'),
            price: Money.parse('0.01'),
          ),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('0.01')),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['grossSale'].value, Decimal.parse('0.00'));
      expect(result['totalAfterItemDiscounts'].value, Decimal.parse('0.00'));
      expect(result['netSale'].value, Decimal.zero);
      expect(result['finalAmount'].value, Decimal.zero);
    });

    test('Zero order discount does not change net sale', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('1.0'),
            price: Money.parse('100.00'),
          ),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.zero),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['grossSale'].value, Decimal.parse('100.00'));
      expect(result['totalAfterItemDiscounts'].value, Decimal.parse('100.00'));
      expect(result['netSale'].value, Decimal.parse('100.00'));
      expect(result['finalAmount'].value, Decimal.parse('100.00'));
    });

    test('Order discount less than item discount', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('1.0'),
            price: Money.parse('100.00'),
            discount: Discount(isPercent: true, value: Decimal.parse('0.5')),
          ),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('10.00')),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['totalAfterItemDiscounts'].value, Decimal.parse('50.00'));
      expect(result['netSale'].value, Decimal.parse('40.00'));
      expect(result['finalAmount'].value, Decimal.parse('40.00'));
    });

    test('High precision calculation with small numbers', () {
      Order order = Order(
        items: [
          OrderItem(
            quantity: Decimal.parse('0.0001'),
            price: Money.parse('0.0001'),
            discount: Discount(isPercent: true, value: Decimal.parse('0.0001')),
          ),
        ],
        orderDiscounts: [
          DiscountType(amount: Money.parse('0.0001')),
        ],
      );

      var result = order.recalculateOrder();
      expect(result['grossSale'].value, Decimal.parse('0.00'));
      expect(result['totalAfterItemDiscounts'].value, Decimal.parse('0.00'));
      expect(result['netSale'].value, Decimal.parse('0.00'));
      expect(result['finalAmount'].value, Decimal.parse('0.00'));
    });

    test('Negative values not allowed for prices', () {
      expect(
        () => OrderItem(
          quantity: Decimal.parse('1.0'),
          price: Money.parse('-100.00'),
        ),
        throwsArgumentError,
      );
    });

    test('Negative values not allowed for discounts', () {
      expect(
        () => Discount(isPercent: true, value: Decimal.parse('-0.1')),
        throwsArgumentError,
      );
    });
  });
}
