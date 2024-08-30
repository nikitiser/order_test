import 'package:decimal/decimal.dart'; // Импорт пакета 'decimal' для работы с точными десятичными числами.

class Money {
  final Decimal value;

  // Конструктор с проверкой и округлением значения
  Money({required Decimal value}) : value = _validateAndRound(value);

  // Фабричный метод для создания объекта Money из строки.
  factory Money.parse(String source) {
    return Money(value: Decimal.parse(source));
  }

  // Метод для проверки и округления значения до двух знаков после запятой.
  static Decimal _validateAndRound(Decimal value) {
    if (value < Decimal.zero) {
      throw ArgumentError('Value cannot be negative: $value');
    }
    return value.round(scale: 2);
  }

  // Переопределение операторов для объекта Money.
  Money operator +(Money other) => Money(value: _validateAndRound(value + other.value));
  Money operator -(Money other) => Money(value: _validateAndRound(value - other.value));
  Money operator /(Money divisor) {
    Decimal result = (value / divisor.value).toDecimal(scaleOnInfinitePrecision: 3).round(scale: 2);
    return Money(value: _validateAndRound(result));
  }

  Money operator *(Money multiplier) {
    Decimal result = (value * multiplier.value).round(scale: 2);
    return Money(value: _validateAndRound(result));
  }

  Money operator %(Money divisor) => Money(value: _validateAndRound(value % divisor.value));
  Money operator ~/(Money divisor) {
    Decimal result = (value ~/ divisor.value).toDecimal();
    return Money(value: _validateAndRound(result));
  }

  // Сравнение значений Money.
  bool operator <(Money other) => value < other.value;
  bool operator <=(Money other) => value <= other.value;
  bool operator >(Money other) => value > other.value;
  bool operator >=(Money other) => value >= other.value;

  @override
  String toString() => value.toStringAsFixed(2);

  static Money get zero => Money(value: Decimal.zero);
}

// Класс для представления скидки.
class Discount {
  final bool isPercent;
  final Decimal value;

  Discount({required this.isPercent, required this.value}) {
    if (value < Decimal.zero) {
      throw ArgumentError('Discount value cannot be negative: $value');
    }
  }

  @override
  String toString() => 'Discount(isPercent: $isPercent, value: $value)';
}

// Класс для представления типа скидки.
class DiscountType {
  final Money amount; // Сумма скидки.

  DiscountType({
    required this.amount,
  });

  @override
  String toString() => 'DiscountType(amount: $amount)'; // Преобразование типа скидки в строку.
}

// Класс для представления налога.
class Tax {
  final String name; // Название налога.
  final Decimal percent; // Процентная ставка налога.

  Tax({required this.name, required this.percent});

  @override
  String toString() => 'Tax(name: $name, percent: $percent)'; // Преобразование налога в строку.
}

// Класс для представления элемента заказа.
class OrderItem {
  final Decimal quantity;
  final Money price;
  final Discount? discount;
  final List<Tax> taxes;

  OrderItem({
    required this.quantity,
    required this.price,
    this.discount,
    this.taxes = const [],
  }) {
    if (price.value < Decimal.zero) {
      throw ArgumentError('Price cannot be negative: ${price.value}');
    }
  }

  Money get initialCost => Money(value: quantity * price.value);

  Money get individualDiscountAmount {
    if (discount == null) return Money.parse('0.0');
    return discount!.isPercent ? Money(value: initialCost.value * discount!.value) : Money(value: discount!.value);
  }

  Money applyDiscount() => initialCost - individualDiscountAmount;

  @override
  String toString() => 'OrderItem(quantity: $quantity, price: $price, discount: $discount, taxes: $taxes)';
}

// Класс для представления заказа.
class Order {
  final List<OrderItem> items;
  final List<DiscountType> orderDiscounts;
  final bool isTaxDisabled;

  Order({
    required this.items,
    this.orderDiscounts = const [],
    this.isTaxDisabled = false,
  });

  Map<String, dynamic> recalculateOrder() {
    Money grossSale = calculateGrossSale();
    Money totalAfterItemDiscounts = _calculateTotalAfterItemDiscounts();
    Money totalOrderDiscount = _calculateTotalOrderDiscount();

    List<Map<String, dynamic>> itemsDetails = _distributeDiscountsToItems(totalAfterItemDiscounts, totalOrderDiscount);
    Money netSale = itemsDetails.fold(Money.zero, (sum, item) => sum + item['finalCost']);

    Map<String, Money> totalTaxesByType = _calculateTaxes(itemsDetails);

    Money totalTaxAmount = totalTaxesByType.values.fold(Money.zero, (sum, tax) => sum + tax);
    Money finalAmount = netSale + totalTaxAmount;

    return {
      'grossSale': grossSale,
      'totalAfterItemDiscounts': totalAfterItemDiscounts,
      'totalOrderDiscount': totalOrderDiscount,
      'netSale': netSale,
      'totalTaxesByType': totalTaxesByType,
      'finalAmount': finalAmount,
      'itemsDetails': itemsDetails
    };
  }

  Money calculateGrossSale() {
    Money grossSale = Money.parse('0.0');
    for (var item in items) {
      grossSale += item.initialCost;
    }
    return grossSale;
  }

  Money _calculateTotalAfterItemDiscounts() {
    Money total = Money.parse('0.0');
    for (var item in items) {
      total += item.applyDiscount();
    }
    return total;
  }

  Money _calculateTotalOrderDiscount() {
    Money totalOrderDiscount = Money.parse('0.0');
    for (var discount in orderDiscounts) {
      totalOrderDiscount += discount.amount;
    }
    return totalOrderDiscount;
  }

  List<Map<String, dynamic>> _distributeDiscountsToItems(Money totalAfterItemDiscounts, Money totalOrderDiscount) {
    List<Map<String, dynamic>> itemsDetails = [];
    Decimal distributedDiscount = Decimal.zero;
    List<Decimal> fractionalParts = [];

    if (totalAfterItemDiscounts.value == Decimal.zero) {
      for (var item in items) {
        Money initialCost = item.initialCost;
        Money individualDiscountAmount = item.individualDiscountAmount;

        itemsDetails.add({
          'item': item,
          'initialCost': initialCost,
          'individualDiscountAmount': individualDiscountAmount,
          'orderDiscountAmount': Money.zero,
          'totalDiscountAmount': individualDiscountAmount,
          'finalCost': initialCost - individualDiscountAmount
        });
      }
      return itemsDetails;
    }

    for (var item in items) {
      Money initialCost = item.initialCost;
      Money individualDiscountAmount = item.individualDiscountAmount;
      Money discountedCost = initialCost - individualDiscountAmount;

      Decimal ratio = (discountedCost.value / totalAfterItemDiscounts.value).toDecimal(scaleOnInfinitePrecision: 20);
      // Округляем в минус чтоб не было перебора по общей сумме
      Decimal baseDiscount = (totalOrderDiscount.value * ratio).floor(scale: 2);

      Money roundedDiscount = Money(value: baseDiscount);
      distributedDiscount += roundedDiscount.value;

      Decimal fractionalPart = (totalOrderDiscount.value * ratio) - roundedDiscount.value;
      fractionalParts.add(fractionalPart);

      itemsDetails.add({
        'item': item,
        'initialCost': initialCost,
        'individualDiscountAmount': individualDiscountAmount,
        'orderDiscountAmount': roundedDiscount,
        'totalDiscountAmount': individualDiscountAmount + roundedDiscount,
        'finalCost': discountedCost - roundedDiscount
      });
    }

    Decimal remainingDiscount = totalOrderDiscount.value - distributedDiscount;
    
    // Распределяем оставшуюся скидку //TODO: Переделать на цикл?
    if (remainingDiscount != Decimal.zero) {
      int indexToAdjust = fractionalParts.indexOf(fractionalParts.reduce((a, b) => a > b ? a : b));
      itemsDetails[indexToAdjust]['orderDiscountAmount'] =
          itemsDetails[indexToAdjust]['orderDiscountAmount'] + Money(value: remainingDiscount);
      itemsDetails[indexToAdjust]['totalDiscountAmount'] =
          itemsDetails[indexToAdjust]['totalDiscountAmount'] + Money(value: remainingDiscount);
      itemsDetails[indexToAdjust]['finalCost'] =
          itemsDetails[indexToAdjust]['finalCost'] - Money(value: remainingDiscount);
    }

    return itemsDetails;
  }

  Map<String, Money> _calculateTaxes(List<Map<String, dynamic>> itemsDetails) {
    Map<String, Money> totalTaxesByType = <String, Money>{};

    for (var itemDetail in itemsDetails) {
      OrderItem item = itemDetail['item'];
      Money finalCost = itemDetail['finalCost'];

      if (!isTaxDisabled && item.taxes.isNotEmpty) {
        for (var tax in item.taxes) {
          Money taxAmount = Money(value: finalCost.value * tax.percent);

          totalTaxesByType.update(
            tax.name,
            (existing) => existing + taxAmount,
            ifAbsent: () => taxAmount,
          );
        }
      }
    }

    return totalTaxesByType;
  }

  @override
  String toString() => 'Order(items: $items, orderDiscounts: $orderDiscounts, isTaxDisabled: $isTaxDisabled)';
}
