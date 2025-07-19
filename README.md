# 🚑 Decentralized Ambulance Payment System

A smart contract-based payment system that automatically triggers payments when ambulance services are completed, ensuring secure and transparent transactions between patients and emergency service providers.

## 🌟 Features

- **🔐 Secure Escrow System**: Payments are held in escrow until service completion
- **🏥 Provider Registration**: Verified ambulance service providers with ratings
- **👤 Patient Profiles**: Medical information and service history tracking
- **💰 Automatic Payment Release**: Smart contract triggers payment upon service completion
- **⭐ Rating System**: Patients can rate providers to maintain service quality
- **🔄 Refund Protection**: Automatic refunds if service is not completed within timeframe
- **📊 Transparent Pricing**: Distance-based pricing with emergency surcharges

## 🚀 Quick Start

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Setup

1. Clone the repository
2. Run `clarinet check` to verify contract compilation
3. Deploy to testnet or mainnet

## 📋 Contract Functions

### 👨‍⚕️ Provider Registration

```clarity
(register-provider "Emergency Care LLC" "AMB-2024-001" "contact@emergencycare.com")
```

### 👤 Patient Registration

```clarity
(register-patient "John Doe" "+1-555-0123" "Type 1 Diabetes, Allergic to Penicillin")
```

### 🚨 Request Ambulance Service

```clarity
(request-ambulance 
  'ST1PROVIDER... 
  "Emergency Transport" 
  u8 
  "123 Main St" 
  "City General Hospital" 
  u15)
```

Parameters:
- `provider`: Provider's Stacks address
- `service-type`: Type of ambulance service
- `emergency-level`: 1-10 (affects pricing)
- `pickup-location`: Where to pick up patient
- `destination`: Hospital or medical facility
- `distance-km`: Distance in kilometers

### 💳 Payment Flow

1. **Deposit Payment**
```clarity
(deposit-payment u1)
```

2. **Complete Service** (Provider only)
```clarity
(complete-service u1)
```

3. **Release Payment** (Patient only)
```clarity
(release-payment u1)
```

### ⭐ Submit Review

```clarity
(submit-review u1 u9 "Excellent service, very professional staff")
```

## 💰 Pricing Structure

- **Base Cost**: 1000 µSTX per kilometer
- **Emergency Surcharge**: 10% additional for emergency level > 5
- **Platform Fee**: 5% of total cost

### Example Calculation
- Distance: 10 km
- Emergency Level: 7
- Base Cost: 10,000 µSTX
- Emergency Surcharge: 1,000 µSTX (10%)
- Total: 11,000 µSTX
- Platform Fee: 550 µSTX
- Provider Receives: 10,450 µSTX

## 🔒 Security Features

- **Access Control**: Only authorized users can perform specific actions
- **Payment Protection**: Funds held in escrow until service completion
- **Time-based Refunds**: Automatic refund eligibility after 144 blocks (~24 hours)
- **Provider Verification**: Only verified providers can accept service requests

## 📊 Read-Only Functions

- `get-service`: Get service details by ID
- `get-provider`: Get provider information
- `get-patient`: Get patient profile
- `get-payment-info`: Get payment status
- `get-service-review`: Get service rating and review
- `calculate-service-cost`: Preview cost before booking

## 🛠️ Administration

### Verify Provider (Contract Owner Only)
```clarity
(verify-provider 'ST1PROVIDER...)
```

### Update Platform Fee (Contract Owner Only)
```clarity
(update-platform-fee u3)
```

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

## 🔍 Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Invalid service parameters |
| u102 | Insufficient payment |
| u103 | Service not found |
| u104 | Service already completed |
| u105 | Service already paid |
| u106 | Invalid provider |
| u107 | Invalid patient |
| u108 | Service not authorized |
| u109 | Refund not allowed |


## 📄 License

This project is open source and available under the MIT License.


*Built with ❤️ for emergency healthcare accessibility*
