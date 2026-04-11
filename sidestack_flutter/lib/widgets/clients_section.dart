import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ClientsSection extends StatelessWidget {
  final Map<String, double> clientRevenue; // aggregated across all stacks
  final String symbol;
  const ClientsSection({
    super.key,
    required this.clientRevenue,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final sortedClients = clientRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'YOUR CLIENTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),

          // Client list or empty state
          if (sortedClients.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No clients tracked yet — add a client name when logging income',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textSecondary,
                ),
              ),
            )
          else
            ...sortedClients.map((entry) {
              final clientName = entry.key;
              final revenue = entry.value;
              final firstLetter =
                  clientName.isNotEmpty ? clientName[0].toUpperCase() : '?';

              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              firstLetter,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Client name
                        Expanded(
                          child: Text(
                            clientName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        // Revenue amount
                        Text(
                          '$symbol${revenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Courier',
                            color: AppTheme.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry != sortedClients.last)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: theme.border),
                    ),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }
}
