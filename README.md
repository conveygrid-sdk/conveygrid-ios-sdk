# SammatiNoticeSDK — iOS

Native Swift/iOS SDK for **Sammati Consent & Notice Management Platform**.

[![Platform](https://img.shields.io/badge/Platform-iOS%2015.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-green.svg)](https://cocoapods.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

---

## 🚀 Features

- **Dynamic Server-Driven Branding**: Automatically styles Notice UIs using server response theme colors (`primary_color`, `secondary_color`), custom typography (`font_family`), and logo images (HTTP/HTTPS or Base64 Data URIs).
- **Adult & Minor Consent Flows**: Fully integrated minor date-of-birth checking, parent/guardian verification, and invitation links.
- **Apple Privacy Compliant**: Includes built-in `PrivacyInfo.xcprivacy` manifest for May 2024+ App Store requirements.
- **Multiple Integration Options**: Supports **Swift Package Manager (SPM)** and **CocoaPods**.

---

## 📦 Installation

### 1. Swift Package Manager (SPM)
In Xcode:
1. Go to **File → Add Package Dependencies...**
2. Enter your repository URL:
   ```
   https://github.com/YOUR_ORGANIZATION/SammatiNoticeSDK.git
   ```
3. Select version `1.0.0` or latest release.

### 2. CocoaPods
Add the following line to your `Podfile`:

```ruby
pod 'SammatiNoticeSDK', '~> 1.0.0'
```

*Or install directly from Git repo:*
```ruby
pod 'SammatiNoticeSDK', :git => 'https://github.com/YOUR_ORGANIZATION/SammatiNoticeSDK.git', :tag => '1.0.0'
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

This SDK includes an official **`PrivacyInfo.xcprivacy`** manifest file to ensure 100% compliance with Apple App Store submission rules:

- **Required Reason API**: `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`) for managing local session IDs and pending consent links.
- **Collected Data Types**:
  - `EmailAddress` (App Functionality, linked to user)
  - `PhoneNumber` (App Functionality, linked to user)
  - `Name` (App Functionality, linked to user)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
# conveygrid-ios-sdk
# conveygrid-ios-sdk
# conveygrid-ios-sdk
