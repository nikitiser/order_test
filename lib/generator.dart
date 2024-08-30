import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:order/order.dart';

Random random = Random();

// Генератор случайных элементов заказа
OrderItem generateRandomOrderItem() {
  Decimal quantity = Decimal.parse((random.nextDouble() * 100).toStringAsFixed(2)); // Количество от 0 до 100
  Money price = Money.parse((random.nextDouble() * 1000).toStringAsFixed(2)); // Цена от 0 до 1000
  bool hasDiscount = random.nextBool();
  Discount? discount = hasDiscount
      ? Discount(
          isPercent: true,
          value: Decimal.parse((random.nextDouble() * 1).toStringAsFixed(2)), // Скидка до 100%
        )
      : null;

  List<Tax> taxes = [];
  if (random.nextBool()) taxes.add(Tax(name: 'GST', percent: Decimal.parse('0.05')));
  if (random.nextBool()) taxes.add(Tax(name: 'HST', percent: Decimal.parse('0.02')));
  if (random.nextBool()) taxes.add(Tax(name: 'TST', percent: Decimal.parse('0.01')));

  return OrderItem(quantity: quantity, price: price, discount: discount, taxes: taxes);
}

// Генератор случайного заказа
Order generateRandomOrder() {
  int numberOfItems = random.nextInt(10) + 1; // Количество элементов от 1 до 10
  List<OrderItem> items = List.generate(numberOfItems, (_) => generateRandomOrderItem());
  final maxDiscount =
      items.fold(Money.zero, (sum, item) => sum + item.applyDiscount()); // Максимальная сумма скидки на заказ
  bool hasOrderDiscount = random.nextBool();
  List<DiscountType> orderDiscounts = hasOrderDiscount
      ? [
          DiscountType(
            amount: Money.parse(
                (random.nextDouble() * maxDiscount.value.toDouble()).toStringAsFixed(2)), // Скидка на заказ до 20
          )
        ]
      : [];

  bool isTaxDisabled = random.nextBool();

  return Order(
    items: items,
    orderDiscounts: orderDiscounts,
    isTaxDisabled: isTaxDisabled,
  );
}

// Тестирование заказа
void testOrderCalculation(Order order) {
  Map<String, dynamic> result = order.recalculateOrder();

  // Проверка валидности расчетов
  Money grossSale = Money.parse('0.0');
  Money totalAfterItemDiscounts = Money.parse('0.0');
  for (var item in order.items) {
    grossSale += item.initialCost;
    totalAfterItemDiscounts += item.applyDiscount();
  }

  Money expectedGrossSale = result['grossSale'];
  Money expectedTotalAfterItemDiscounts = result['totalAfterItemDiscounts'];

  assert(grossSale.value == expectedGrossSale.value, 'Ошибка в расчете grossSale');
  assert(totalAfterItemDiscounts.value == expectedTotalAfterItemDiscounts.value,
      'Ошибка в расчете totalAfterItemDiscounts');

  // Проверка, что итоговая сумма соответствует сумме чистой продажи и налогов
  Money netSale = result['netSale'];
  Money totalTaxAmount = result['totalTaxesByType'].values.fold(Money.zero, (sum, tax) => sum + tax);
  Money finalAmount = result['finalAmount'];

  assert(finalAmount.value == (netSale + totalTaxAmount).value, 'Ошибка в расчете finalAmount');

  // Проверка на отрицательные значения
  assert(grossSale.value >= Decimal.zero, 'Общая стоимость grossSale не должна быть отрицательной');
  assert(
      totalAfterItemDiscounts.value >= Decimal.zero, 'Сумма после индивидуальных скидок не должна быть отрицательной');
  assert(netSale.value >= Decimal.zero, 'Чистая продажа netSale не должна быть отрицательной');
  assert(finalAmount.value >= Decimal.zero, 'Итоговая сумма finalAmount не должна быть отрицательной');
  for (var tax in result['totalTaxesByType'].values) {
    assert(tax.value >= Decimal.zero, 'Сумма налогов не должна быть отрицательной');
  }
}
