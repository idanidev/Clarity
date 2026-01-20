# Clarity Firebase Cloud Functions

This directory contains the Firebase Cloud Functions for automatic recurring expense processing.

## Setup

### Prerequisites
- Node.js 18 or higher
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase project configured

### Installation

1. Navigate to the functions directory:
   ```bash
   cd functions
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Login to Firebase (if not already logged in):
   ```bash
   firebase login
   ```

4. Initialize Firebase project (if not already done):
   ```bash
   firebase init
   ```
   Select "Functions" and choose your existing Firebase project.

## Deployment

### Deploy all functions:
```bash
npm run deploy
```

### Deploy specific function:
```bash
firebase deploy --only functions:processRecurringExpenses
```

## Functions

### `processRecurringExpenses`
**Type:** Scheduled (PubSub)
**Schedule:** Daily at 9:00 AM (configurable timezone)
**Purpose:** Automatically processes all active recurring expenses and creates expense entries when due.

**Logic:**
- Runs daily at scheduled time
- Checks all active recurring expenses across all users
- Creates expenses for those due today based on:
  - `dayOfMonth`: Must match current day
  - `frequency`: monthly, quarterly, semestral, or yearly
  - `billingMonth`: Required for non-monthly frequencies
  - `lastCreated`: Prevents duplicate charges on same day

**Timezone Configuration:**
Edit `index.js` line 20 to set your timezone:
```javascript
.timeZone('America/Los_Angeles') // Change to your timezone
```

Common timezones:
- `America/New_York` (EST/EDT)
- `America/Chicago` (CST/CDT)
- `America/Denver` (MST/MDT)
- `America/Los_Angeles` (PST/PDT)
- `Europe/Madrid` (CET/CEST)
- `America/Mexico_City` (CST)

### `processRecurringExpensesManual`
**Type:** Callable HTTPS function
**Purpose:** Manual trigger for testing or immediate processing

**Usage from iOS app:**
```swift
let functions = Functions.functions()
functions.httpsCallable("processRecurringExpensesManual").call { result, error in
    if let error = error {
        print("Error: \(error)")
    } else {
        print("Success: \(result?.data ?? "null")")
    }
}
```

## Testing

### Local testing with Firebase Emulator:
```bash
npm run serve
```

### View logs:
```bash
npm run logs
```

### Monitor in Firebase Console:
1. Go to Firebase Console
2. Select your project
3. Navigate to "Functions" in the left menu
4. View execution logs and metrics

## Frequency Logic

### Monthly
- Charges every month on `dayOfMonth`
- `billingMonth` not required

### Quarterly
- Charges every 3 months starting from `billingMonth`
- Example: `billingMonth=1` → charges in January, April, July, October

### Semestral (Biannual)
- Charges every 6 months starting from `billingMonth`
- Example: `billingMonth=1` → charges in January, July

### Yearly/Annual
- Charges once per year in `billingMonth` on `dayOfMonth`
- Example: `billingMonth=6, dayOfMonth=15` → charges June 15th every year

## Troubleshooting

### Function not running on schedule
- Check Firebase Console → Functions for errors
- Verify billing is enabled (Cloud Scheduler requires Blaze plan)
- Check function logs for execution history

### Expenses not being created
- Verify `active: true` on recurring expenses
- Check `dayOfMonth` matches current day
- Verify `billingMonth` is set for non-monthly frequencies
- Check logs for detailed error messages

### Duplicate expenses
- Function checks `lastCreated` field to prevent duplicates
- If duplicates occur, check timezone settings
- Verify clock synchronization on your devices

## Cost Estimation

**Cloud Scheduler:** ~$0.10/month for daily schedule
**Cloud Functions:**
- ~30 invocations/month (daily)
- Average <1 second execution time
- **Estimate:** $0-$1/month (likely free tier)

**Total:** ~$0.10-$1.10/month

## Security

- Functions run with Firebase Admin SDK privileges
- Manual trigger requires authentication
- User data isolation via Firestore security rules
- All operations logged for audit trail
