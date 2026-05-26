# SidestacksWidget — Xcode Setup

All Swift source files are already written. You just need to add the extension
target to Xcode and wire the entitlements.  Takes about 5 minutes.

---

## 1 — Add the Widget Extension target

1. Open `Runner.xcworkspace` in Xcode
2. **File → New → Target…**
3. Choose **Widget Extension** (under iOS)
4. Fill in:
   - Product Name: **SidestacksWidget**
   - Team: your team (`5JKK77ZDG8`)
   - Bundle Identifier: `com.sidestacks.app.SidestacksWidget`
   - Include Configuration Intent: **No**
5. Click **Finish**
6. When Xcode asks "Activate SidestacksWidget scheme?", click **Cancel** (keep Runner active)

---

## 2 — Replace the auto-generated Swift file

Xcode will create `SidestacksWidget.swift` with placeholder content.  
**Delete it** and replace it (or let Xcode use the existing file):

- In the Project navigator, right-click the `SidestacksWidget` group
- Choose **Add Files to "Runner"…**
- Select `ios/SidestacksWidget/SidestacksWidget.swift` (the one I wrote)
- Make sure "SidestacksWidget" target is checked

---

## 3 — Set the entitlements file

1. Select the **SidestacksWidget** target in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability** → add **App Groups**
4. Add group: `group.com.sidestacks.app`
5. In **Build Settings**, search for "Code Signing Entitlements"
6. Set it to: `SidestacksWidget/SidestacksWidget.entitlements`

---

## 4 — Add App Group to the Runner target too

1. Select the **Runner** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** → add **App Groups** (if not already there)
4. Add group: `group.com.sidestacks.app`

Runner.entitlements already has the key — Xcode just needs to register it.

---

## 5 — Link WidgetKit framework in Runner (for AppDelegate)

`AppDelegate.swift` imports `WidgetKit`.  Runner needs it linked:

1. Select the **Runner** target → **General → Frameworks, Libraries and Embedded Content**
2. Click **+** → search **WidgetKit.framework** → Add
3. Set it to **Do Not Embed**

---

## 6 — Set minimum iOS deployment target

WidgetKit requires iOS 14+.

1. Select the **SidestacksWidget** target → **General**
2. Set **Minimum Deployments** to **iOS 14.0**

---

## 7 — Build and test

- Run on a device (widgets don't work in Simulator before iOS 17)
- Long-press the home screen → **+** → search "SideStacks"
- Add the small or medium widget
- Open the app — the widget should update within seconds

---

## How data flows

```
AppProvider._syncWidgetData()
  → MethodChannel("com.sidestacks.app/widget")
    → AppDelegate (Swift)
      → UserDefaults(suiteName: "group.com.sidestacks.app")
        → SidestacksWidget reads on next refresh
```

The widget also self-refreshes every 15 minutes as a safety net.
