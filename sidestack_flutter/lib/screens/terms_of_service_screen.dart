import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: theme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Terms of Service',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lastUpdated(theme),
            const SizedBox(height: 24),
            _section(
              theme,
              'Agreement to Terms',
              'These Terms of Service ("Terms") govern your use of the SideStacks mobile application '
              '("App") operated by SideStacks Pty Ltd (ACN pending) ("we", "us", "our"). By creating '
              'an account or using the App, you agree to be bound by these Terms. If you do not agree, '
              'please do not use the App.\n\n'
              'These Terms are governed by the laws of New South Wales, Australia. Any disputes will '
              'be subject to the exclusive jurisdiction of the courts of New South Wales.',
            ),
            _section(
              theme,
              '1. Description of Service',
              'SideStacks is a personal finance tracking application designed for individuals who '
              'manage one or more side hustles, freelance projects, or small businesses. The App '
              'allows you to:\n\n'
              '• Record income and expense transactions\n'
              '• Generate financial summaries and reports\n'
              '• Track mileage and business expenses\n'
              '• Create and send invoices to clients\n'
              '• View AI-generated financial insights\n'
              '• Export financial data as PDF or CSV\n\n'
              'The App is available in a free tier with limited features and a Pro subscription with '
              'full access.',
            ),
            _section(
              theme,
              '2. Eligibility',
              'You must be at least 18 years of age to create an account and use the App. By using '
              'the App, you represent and warrant that you meet this age requirement and that you '
              'have the legal capacity to enter into these Terms.',
            ),
            _section(
              theme,
              '3. Account Registration',
              'You are responsible for maintaining the confidentiality of your account credentials '
              'and for all activity that occurs under your account. You must:\n\n'
              '• Provide accurate and complete information when registering\n'
              '• Keep your password secure and not share it with others\n'
              '• Notify us immediately of any unauthorised use of your account\n'
              '• Not create accounts using automated means or under false pretences\n\n'
              'We reserve the right to suspend or terminate accounts that violate these Terms.',
            ),
            _section(
              theme,
              '4. Subscriptions and Billing',
              'SideStacks Pro is available as a monthly or annual subscription. Subscriptions are '
              'processed through Apple App Store or Google Play Store, and are subject to their '
              'respective billing terms.\n\n'
              'Free Trial — Where a free trial is offered, you will not be charged until the trial '
              'period ends. Cancel before the trial ends to avoid being charged.\n\n'
              'Automatic Renewal — Subscriptions automatically renew unless cancelled at least '
              '24 hours before the end of the current billing period. You can manage and cancel '
              'subscriptions in your App Store / Play Store account settings.\n\n'
              'Refunds — Refund requests are handled by Apple or Google in accordance with their '
              'policies. We do not process refunds directly.\n\n'
              'Price Changes — We may change subscription prices with reasonable notice. Continued '
              'use after a price change constitutes acceptance of the new price.',
            ),
            _section(
              theme,
              '5. Not Financial or Tax Advice',
              'IMPORTANT: The App is a financial tracking and record-keeping tool only. Nothing in '
              'the App constitutes financial, investment, tax, accounting, or legal advice.\n\n'
              'Tax estimates shown in the App are approximate calculations for illustrative purposes '
              'only and should not be relied upon for tax lodgement or financial planning. Tax '
              'obligations vary by jurisdiction, income type, and individual circumstances.\n\n'
              'AI-generated summaries and insights are informational only and may contain errors. '
              'Always consult a qualified accountant, tax agent, or financial adviser for advice '
              'tailored to your situation.\n\n'
              'We are not responsible for any financial decisions made based on information provided '
              'by the App.',
            ),
            _section(
              theme,
              '6. Acceptable Use',
              'You agree to use the App only for lawful purposes and in accordance with these Terms. '
              'You must not:\n\n'
              '• Use the App for any fraudulent or unlawful purpose\n'
              '• Attempt to gain unauthorised access to any part of the App or its systems\n'
              '• Reverse engineer, decompile, or disassemble any part of the App\n'
              '• Use the App to store, transmit, or distribute any illegal or harmful content\n'
              '• Interfere with or disrupt the integrity or performance of the App\n'
              '• Use automated tools (bots, scrapers) to access the App without our written consent',
            ),
            _section(
              theme,
              '7. Your Data',
              'You retain ownership of all financial data and content you enter into the App. By '
              'using the App, you grant us a limited licence to store and process your data solely '
              'for the purpose of providing the App\'s services to you.\n\n'
              'You are responsible for the accuracy of the data you enter. We recommend keeping '
              'your own backups of important financial records, as we cannot guarantee that data '
              'will not be lost due to technical issues.',
            ),
            _section(
              theme,
              '8. Intellectual Property',
              'All intellectual property in the App — including its design, code, branding, and '
              'content created by us — is owned by SideStacks Pty Ltd or our licensors. You are '
              'granted a limited, non-exclusive, non-transferable licence to use the App for '
              'personal, non-commercial purposes in accordance with these Terms.\n\n'
              'You may not copy, modify, distribute, or create derivative works based on the App '
              'without our written permission.',
            ),
            _section(
              theme,
              '9. Disclaimer of Warranties',
              'THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, '
              'EITHER EXPRESS OR IMPLIED. TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE DISCLAIM ALL '
              'WARRANTIES, INCLUDING BUT NOT LIMITED TO:\n\n'
              '• Warranties of merchantability or fitness for a particular purpose\n'
              '• Warranties that the App will be uninterrupted, error-free, or secure\n'
              '• Warranties regarding the accuracy or completeness of any information in the App\n\n'
              'Nothing in these Terms excludes any statutory guarantee or warranty that cannot be '
              'excluded under Australian Consumer Law.',
            ),
            _section(
              theme,
              '10. Limitation of Liability',
              'To the maximum extent permitted by applicable law, SideStacks Pty Ltd and its '
              'directors, employees, and contractors shall not be liable for any indirect, '
              'incidental, special, consequential, or punitive damages, including loss of profits, '
              'data, or business opportunities, arising from your use of or inability to use the App.\n\n'
              'Our total liability to you for any claim arising from your use of the App is limited '
              'to the amount you paid for the App in the 12 months preceding the claim, or AUD $10, '
              'whichever is greater.\n\n'
              'Nothing in these Terms limits liability for death or personal injury caused by '
              'negligence, fraud, or any liability that cannot be limited under Australian Consumer Law.',
            ),
            _section(
              theme,
              '11. Termination',
              'You may stop using the App and delete your account at any time. We may suspend or '
              'terminate your access if you violate these Terms or if we decide to discontinue the App.\n\n'
              'Upon termination, your right to use the App ceases immediately. We will retain or '
              'delete your data in accordance with our Privacy Policy.',
            ),
            _section(
              theme,
              '12. Changes to These Terms',
              'We may update these Terms from time to time. We will notify you of material changes '
              'by posting the updated Terms in the App and, where appropriate, by email. Your '
              'continued use of the App after changes take effect constitutes acceptance of the '
              'updated Terms.\n\n'
              'If you do not agree to the updated Terms, you must stop using the App.',
            ),
            _section(
              theme,
              '13. Contact Us',
              'If you have any questions about these Terms, please contact us at:\n\n'
              'SideStacks Support\n'
              'Email: legal@sidestacks.app\n'
              'Website: https://sidestacks.app',
            ),
          ],
        ),
      ),
    );
  }

  Widget _lastUpdated(AppColors theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(
            'Last updated: 1 April 2025',
            style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _section(AppColors theme, String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
                fontSize: 13,
                color: theme.textSecondary,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}
