# TrueLayer Bank Integration Setup

## 1. Get your TrueLayer credentials

1. Sign up at https://console.truelayer.com
2. Create a new app
3. Under **Allowed redirect URIs**, add: `sidestack://bank-callback`
4. Copy your **Client ID** and **Client Secret**

## 2. Set Firebase environment config

```bash
firebase functions:config:set \
  truelayer.client_id="YOUR_CLIENT_ID" \
  truelayer.client_secret="YOUR_CLIENT_SECRET" \
  truelayer.redirect_uri="sidestack://bank-callback" \
  truelayer.env="sandbox"
```

Change `sandbox` to `live` when you're ready to go live.

## 3. Deploy the Cloud Functions

```bash
cd functions
npm install
npm run deploy
```

## 4. Android — register the deep link

In `android/app/src/main/AndroidManifest.xml`, inside the `<activity>` tag, add:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="sidestack" android:host="bank-callback" />
</intent-filter>
```

## 5. iOS — register the URL scheme

In `ios/Runner/Info.plist`, add:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>sidestack</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.yourcompany.sidestack</string>
  </dict>
</array>
```

## 6. Handle the deep link in main.dart

Add `uni_links` or `app_links` to pubspec.yaml, then in your app initialisation listen for incoming links:

```dart
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';

// In your root widget initState:
final _appLinks = AppLinks();
_appLinks.uriLinkStream.listen((uri) {
  if (uri.scheme == 'sidestack' && uri.host == 'bank-callback') {
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code != null && state != null) {
      context.read<AppProvider>().handleBankCallback(code, state);
    }
  }
});
```

## 7. Test in sandbox

TrueLayer sandbox provides test banks with mock data.
Use credentials: **username: john** / **password: doe** on any test bank.
