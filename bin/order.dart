import 'package:decimal/decimal.dart';
import 'package:order/generator.dart';
import 'package:order/order.dart';

void main() {
  for (int i = 0; i < 100000; i++) {
    final order = generateRandomOrder();
    try {
      testOrderCalculation(order);
    } catch (e) {
      print('Ошибка при тестировании заказа: $e');
      print('Заказ: $order');
      rethrow;
    }
  }
  final order = Order(
    items: [
      OrderItem(
        quantity: Decimal.parse('1'),
        price: Money.parse('0.01'),
      ),
      OrderItem(
        quantity: Decimal.parse('1'),
        price: Money.parse('0.02'),
      ),
      OrderItem(
        quantity: Decimal.parse('1'),
        price: Money.parse('0.07'),
      ),
    ],
    orderDiscounts: [
      DiscountType(amount: Money.parse('0.05')),
    ],
    isTaxDisabled: false,
  );
  print(order.recalculateOrder());
  print('Все тесты прошли успешно!');
}
