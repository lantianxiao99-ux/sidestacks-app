import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
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
              'About This Policy',
              'SideStacks ("we", "us", "our") is an Australian business registered in Western '
              'Australia, trading as SideStacks (ABN 19 813 173 221). This Privacy Policy explains '
              'how we collect, use, disclose, and protect your personal information when you use '
              'the SideStacks mobile application ("the App").\n\n'
              'We are committed to complying with the Australian Privacy Act 1988 (Cth) and the '
              'Australian Privacy Principles (APPs), the UK General Data Protection Regulation '
              '(UK GDPR), and the EU General Data Protection Regulation (GDPR) where applicable.',
            ),
            _section(
              theme,
              '1. Information We Collect',
              'We collect the following categories of information:\n\n'
              'Account Information — When you register, we collect your name, email address, and '
              'password (stored as a secure hash). If you sign in with Google or Apple, we receive '
              'your name and email address from those providers. If you sign in with multiple '
              'providers using the same email address, your accounts are automatically linked under '
              'a single profile.\n\n'
              'Financial Data — Income entries, expense entries, transaction notes, categories, '
              'invoice details, and client information that you enter into the App. This data is '
              'stored on your account and is not shared with third parties for marketing purposes.\n\n'
              'Mileage and Location Data — If you use the mileage tracking feature, we record trip '
              'distances and dates that you log manually. We do not collect continuous GPS or '
              'background location data.\n\n'
              'Profile Photo — If you upload a profile photo, it is stored securely in Firebase Storage '
              'and associated with your account.\n\n'
              'Usage Data — We may collect anonymous usage analytics (e.g. which screens are visited) '
              'to improve the App. This data does not identify you personally.\n\n'
              'Device Information — We may collect device type, operating system version, and app '
              'version for diagnostic and support purposes.',
            ),
            _section(
              theme,
              '2. How We Use Your Information',
              'We use your information to:\n\n'
              '• Provide and maintain the App and its features\n'
              '• Authenticate your account and keep it secure\n'
              '• Generate AI-powered financial summaries and insights (your data is sent to '
              'OpenAI\'s API for processing — see Section 4)\n'
              '• Process in-app purchase subscriptions via RevenueCat\n'
              '• Send optional push notifications about your financial activity\n'
              '• Respond to your support requests\n'
              '• Improve and develop new features\n'
              '• Comply with our legal obligations',
            ),
            _section(
              theme,
              '3. Legal Basis for Processing (GDPR / UK GDPR)',
              'If you are located in the UK or European Economic Area, we process your personal '
              'data on the following legal bases:\n\n'
              '• Contract — processing necessary to provide the App under our Terms of Service\n'
              '• Legitimate Interests — improving the App, preventing fraud, and maintaining security\n'
              '• Consent — for optional push notifications; you may withdraw consent at any time in '
              'your device settings\n'
              '• Legal Obligation — where required by applicable law',
            ),
            _section(
              theme,
              '4. Third-Party Services',
              'We use the following third-party services that may receive your data:\n\n'
              'Firebase (Google LLC) — We use Firebase Authentication, Firestore (database), '
              'Firebase Storage, and Firebase App Check to store your account and financial data '
              'and to protect the App from unauthorised access. Data is stored in Google\'s cloud '
              'infrastructure. Google\'s privacy policy applies: https://policies.google.com/privacy\n\n'
              'OpenAI — When you use the AI Summary feature, selected financial data from your stacks '
              'is sent to OpenAI\'s API to generate insights. OpenAI does not use API data to train '
              'its models. OpenAI\'s privacy policy: https://openai.com/policies/privacy-policy\n\n'
              'RevenueCat — We use RevenueCat to manage in-app subscriptions. RevenueCat may receive '
              'your user ID and purchase events. RevenueCat\'s privacy policy: https://www.revenuecat.com/privacy\n\n'
              'Apple / Google — In-app purchases are processed by Apple (App Store) or Google (Play '
              'Store) under their respective privacy policies.\n\n'
              'We do not sell your personal information to third parties.',
            ),
            _section(
              theme,
              '5. Data Retention',
              'We retain your personal data for as long as your account is active. If you delete '
              'your account, we will delete your personal data within 30 days, except where we are '
              'required to retain it for legal or regulatory purposes.\n\n'
              'You may request deletion of your data at any time by contacting us (see Section 10).',
            ),
            _section(
              theme,
              '6. Your Rights',
              'Depending on your location, you may have the following rights:\n\n'
              '• Access — request a copy of the personal data we hold about you\n'
              '• Correction — request correction of inaccurate or incomplete data\n'
              '• Deletion — request deletion of your personal data ("right to be forgotten")\n'
              '• Portability — request your data in a structured, machine-readable format\n'
              '• Objection — object to certain processing of your data\n'
              '• Restriction — request that we restrict processing of your data\n'
              '• Withdraw Consent — where processing is based on consent, withdraw at any time\n\n'
              'Australian residents may also lodge a complaint with the Office of the Australian '
              'Information Commissioner (OAIC) at www.oaic.gov.au. UK residents may contact the '
              'Information Commissioner\'s Office (ICO) at www.ico.org.uk.',
            ),
            _section(
              theme,
              '7. Data Security',
              'We implement appropriate technical and organisational measures to protect your personal '
              'data against unauthorised access, alteration, disclosure, or destruction. These include '
              'encryption in transit (TLS), secure Firebase security rules, and access controls.\n\n'
              'No method of transmission over the internet or electronic storage is 100% secure. '
              'While we strive to protect your data, we cannot guarantee absolute security.',
            ),
            _section(
              theme,
              '8. Children\'s Privacy',
              'The App is not directed to children under the age of 13 (or 16 in certain '
              'jurisdictions). We do not knowingly collect personal information from children. '
              'If you believe a child has provided us with personal information, please contact us '
              'and we will take steps to delete it.',
            ),
            _section(
              theme,
              '9. International Data Transfers',
              'Your data may be processed and stored in countries outside your own, including the '
              'United States (where Google and OpenAI servers are located). Where required by law, '
              'we ensure appropriate safeguards are in place for such transfers, including standard '
              'contractual clauses.',
            ),
            _section(
              theme,
              '10. Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of material '
              'changes by posting the updated policy in the App and, where appropriate, by sending '
              'you an email notification. Your continued use of the App after changes are posted '
              'constitutes your acceptance of the updated policy.',
            ),
            _section(
              theme,
              '11. Contact Us',
              'If you have any questions, concerns, or requests regarding this Privacy Policy or '
              'your personal data, please contact us at:\n\n'
              'SideStacks Support\n'
              'Email: support@sidestacks.app\n'
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
            'Last updated: 24 April 2026',
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
