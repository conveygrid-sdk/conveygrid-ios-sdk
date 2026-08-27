# SammatiNoticeSDK — iOS

Native Swift/iOS SDK for **Sammati Consent & Notice Management Platform**.

[![Platform](https://img.shields.io/badge/Platform-iOS%2015.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

---

## 🚀 Features

- **Dynamic Server-Driven Branding**: Automatically styles Notice UIs using server response theme colors (`primary_color`, `secondary_color`), custom typography (`font_family`), and logo images (HTTP/HTTPS or Base64 Data URIs).
- **Adult & Minor Consent Flows**: Fully integrated minor date-of-birth checking, parent/guardian verification, and invitation links.
- **Apple Privacy Compliant**: Includes built-in `PrivacyInfo.xcprivacy` manifest for May 2024+ App Store requirements.
- **Swift Package Manager (SPM)**: Native SPM support for modern and lightweight dependency management.

---

## 📦 Installation

### Swift Package Manager (SPM)

#### Via Xcode
1. In Xcode, navigate to **File → Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/conveygrid-sdk/conveygrid-ios-sdk.git
   ```
3. Set the **Dependency Rule** to **Up to Next Major Version** (e.g., `1.0.0`) or your preferred version rule.
4. Select your target and click **Add Package**.

#### Via `Package.swift`
Add `SammatiNoticeSDK` to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/conveygrid-sdk/conveygrid-ios-sdk.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTargetName",
        dependencies: [
            .product(name: "SammatiNoticeSDK", package: "SammatiNoticeSDK")
        ]
    )
]
```

---

## ⚙️ Configuration

Initialize the SDK early in your application lifecycle (e.g. `AppDelegate` or `@main` App init):

```swift
import SammatiNoticeSDK

SammatiNotice.configure(
    SammatiConfiguration(
        clientId: "YOUR_CLIENT_ID",
        apiBaseURL: URL(string: "https://samatigridapidev.rysun.in")!,
        environment: .sandbox, // or .production
        theme: NoticeTheme(    // Optional global theme fallback
            primaryColor: "#005BED",
            secondaryColor: "#F2621B",
            fontFamily: "HelveticaNeue"
        )
    )
)
```

---

## 🎨 Dynamic Theme Configuration

Themes are applied in a **hierarchical order**:
1. **Per-Call Override (`ConsentOptions.theme`)**
2. **Backend Notice Theme (`Notice.theme` returned from published notice API)**
3. **Global SDK Configuration (`SammatiConfiguration.theme`)**
4. **Default System Fallback Theme**

### Server Response Theme Example
The SDK automatically decodes and applies server-driven themes:
```json
{
  "theme": {
    "theme_id": "f3aebb74-65b5-40ed-a6d0-0a0c78fc4e1e",
    "theme_name": "LuxeStay",
    "primary_color": "#005BED",
    "secondary_color": "#F2621B",
    "font_family": "Inter",
    "logo_url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg..."
  }
}
```

- **`primary_color`**: Applied to primary buttons (*Accept All*), switch toggles, and selection highlights.
- **`secondary_color`**: Applied to secondary action buttons (*Accept Selected*).
- **`logo_url`**: Renders HTTP/HTTPS image URLs or Base64 Data URIs (`data:image/png;base64,...`) in the top bar header.

---

## 💻 Usage

### Adult Consent Flow

```swift
let result = try await SammatiNotice.captureConsent(
    options: ConsentOptions(
        noticeCode: "LUXE",
        email: "user@example.com",
        mobile: "9999999999",
        fullName: "Jane Doe"
    ),
    presenter: self
)

if result.allMandatoryGranted {
    print("Consent granted! Artifact ID: \(result.artifactId ?? "")")
}
```

### Minor & Guardian Flow

```swift
let result = try await SammatiNotice.captureConsent(
    options: ConsentOptions(
        noticeCode: "LUXE",
        fullName: "Alex Smith",
        dateOfBirth: "2015-05-10",
        guardian: Guardian(
            guardianName: "Robert Smith",
            guardianEmail: "guardian@example.com",
            guardianMobile: "8888888888",
            relationshipCode: "FATHER"
        )
    ),
    presenter: self
)
```

### Resume Pending Guardian Invitation Link

```swift
let result = try await SammatiNotice.resumePendingLink(
    referenceId: "CUSTOMER_REFERENCE_ID"
)
```

---

## 🔒 Apple Privacy & App Store Compliance

This SDK includes an official embedded **`PrivacyInfo.xcprivacy`** manifest file in full compliance with Apple's privacy manifest and third-party SDK requirements (iOS 17+ / May 2024+ App Store mandate).

### 1. Xcode Privacy Report Verification
When preparing an archive in Xcode:
1. In Xcode, select **Product → Archive**.
2. Once the build appears in the **Organizer**, right-click the archive (or select **Generate Privacy Report**).
3. The exported `PrivacyReport.pdf` will automatically include all declared APIs and data collection types from `SammatiNoticeSDK`.

---

### 2. App Store Connect Configuration Steps (App Privacy Nutrition Label)

When completing the **App Privacy** section in **App Store Connect**, follow the step-by-step instructions below:

#### Step 1: Data Collection Prompt
- Go to **App Store Connect → [Your App] → App Privacy**.
- Select **Get Started** or **Edit**.
- Under *"Do you or your third-party partners collect data from this app?"*, select **Yes, we collect data from this app**.

#### Step 2: Declare Data Types
Select the following **Contact Info** categories collected during consent & notice workflows:

| Data Type | Category | Purpose | Linked to User? | Used for Tracking? |
| :--- | :--- | :--- | :---: | :---: |
| **Name** | Contact Info | **App Functionality** *(User & Guardian identification for consent records)* | **Yes** | **No** |
| **Email Address** | Contact Info | **App Functionality** *(Consent notices, delivery receipts, and guardian invites)* | **Yes** | **No** |
| **Phone Number** | Contact Info | **App Functionality** *(OTP verification & consent lifecycle communication)* | **Yes** | **No** |

#### Step 3: Complete Question Details for Each Data Type
For each data type (**Name**, **Email Address**, **Phone Number**), configure:
1. **How is this data used?**
   - Select: **App Functionality**
2. **Is this data linked to the user’s identity?**
   - Select: **Yes, data collected from this app is linked to the user’s identity**
3. **Do you use this data for tracking purposes?**
   - Select: **No, we do not use this data for tracking purposes**

#### Step 4: Tracking Declaration
- When asked if your app tracks users across apps and websites owned by other companies, select **No**.
- `SammatiNoticeSDK` does not perform cross-app tracking, does not use IDFA / advertising identifiers, and has `NSPrivacyTracking` set to `false`.

---

### 3. Required Reason API Declarations

The embedded `PrivacyInfo.xcprivacy` manifest declares:

- **API Category**: `NSPrivacyAccessedAPICategoryUserDefaults`
- **Reason Code**: `CA92.1`
- **Justification**: Accesses `UserDefaults` strictly within the app's local storage container to persist and retrieve local consent session tokens, pending guardian link reference IDs, and cached notice states.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

