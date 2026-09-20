/// Strongly typed DTOs for Wallet transactions.
library;

class WalletDebitRequestDto {
  final String currency;
  final int amount;
  final String reason;
  final String? referenceId;

  const WalletDebitRequestDto({
    required this.currency,
    required this.amount,
    required this.reason,
    this.referenceId,
  });

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'amount': amount,
    'reason': reason,
    if (referenceId != null) 'reference_id': referenceId,
  };
}

class WalletCreditRequestDto {
  final String currency;
  final int amount;
  final String reason;
  final String? referenceId;

  const WalletCreditRequestDto({
    required this.currency,
    required this.amount,
    required this.reason,
    this.referenceId,
  });

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'amount': amount,
    'reason': reason,
    if (referenceId != null) 'reference_id': referenceId,
  };
}

class WalletBalanceResponseDto {
  final int coins;
  final int gems;

  const WalletBalanceResponseDto({required this.coins, required this.gems});

  factory WalletBalanceResponseDto.fromJson(Map<String, dynamic> json) =>
      WalletBalanceResponseDto(
        coins: json['coins'] as int? ?? 0,
        gems: json['gems'] as int? ?? 0,
      );
}

class WalletTransactionResponseDto {
  final String id;
  final String userId;
  final String currency;
  final String direction;
  final int amount;
  final String reason;
  final int balanceAfter;
  final DateTime createdAt;

  const WalletTransactionResponseDto({
    required this.id,
    required this.userId,
    required this.currency,
    required this.direction,
    required this.amount,
    required this.reason,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory WalletTransactionResponseDto.fromJson(Map<String, dynamic> json) =>
      WalletTransactionResponseDto(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        currency: json['currency'] as String? ?? 'coins',
        direction: json['direction'] as String? ?? 'credit',
        amount: json['amount'] as int? ?? 0,
        reason: json['reason'] as String? ?? '',
        balanceAfter: json['balance_after'] as int? ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

class WalletHistoryResponseDto {
  final List<WalletTransactionResponseDto> transactions;
  final int total;
  final int limit;
  final int offset;

  const WalletHistoryResponseDto({
    required this.transactions,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory WalletHistoryResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['transactions'];
    final items = <WalletTransactionResponseDto>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          items.add(WalletTransactionResponseDto.fromJson(item));
        }
      }
    }
    return WalletHistoryResponseDto(
      transactions: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
    );
  }
}
