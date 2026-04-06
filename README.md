# Monity - iOS Expense Management App

A full-stack expense tracking application with a SwiftUI iOS client and Node.js backend.

## Features

- **Transaction Tracking** - Add income and expenses with categories
- **Budget Management** - Set monthly/weekly/yearly budgets per category with visual alerts
- **Charts & Statistics** - Pie charts, bar charts, and trend lines
- **Multi-Currency** - Support for ILS, USD, EUR, GBP, and more
- **Recurring Transactions** - Automatic daily/weekly/monthly/yearly transactions
- **CSV Export** - Export your data for spreadsheets
- **Bilingual** - Full Hebrew and English support with RTL

## Tech Stack

- **iOS**: SwiftUI, Swift Charts, MVVM architecture
- **Backend**: Node.js, Express, Sequelize ORM
- **Database**: PostgreSQL
- **Auth**: JWT (JSON Web Tokens)

## Getting Started

### Prerequisites

- Xcode 15+ (iOS 17+)
- Node.js 18+
- PostgreSQL 14+

### Backend Setup

```bash
# Navigate to backend
cd backend

# Install dependencies
npm install

# Create .env from example
cp .env.example .env
# Edit .env with your PostgreSQL credentials

# Create the database
createdb monity

# Start the server
npm run dev
```

The server will start on `http://localhost:3000`.

### iOS App Setup

1. Open `MonityApp/` in Xcode
2. Create a new Xcode project (File > New > Project > App)
   - Product Name: MonityApp
   - Interface: SwiftUI
   - Language: Swift
3. Add all the Swift files from the `MonityApp/` directory to the project
4. Add the localization files from `Resources/`
5. Build and run on simulator or device

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login |
| GET | `/api/auth/me` | Current user profile |
| GET/POST | `/api/transactions` | List/Create transactions |
| GET | `/api/transactions/summary` | Monthly summary |
| GET/POST | `/api/categories` | List/Create categories |
| GET/POST | `/api/budgets` | List/Create budgets |
| GET | `/api/budgets/status` | Budget spending status |
| GET/POST | `/api/recurring` | Recurring rules |
| GET | `/api/export/csv` | Export to CSV |
| GET | `/api/currencies/rates` | Exchange rates |
| GET | `/api/currencies/supported` | Supported currencies |
