/**
 * Clarity Firebase Cloud Functions
 *
 * This file contains scheduled functions for automatic expense processing
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Scheduled function that runs daily at 9:00 AM UTC (adjust timezone as needed)
 * Processes all active recurring expenses and creates expense entries when due
 */
exports.processRecurringExpenses = functions.pubsub
  .schedule("0 9 * * *") // Every day at 9:00 AM UTC
  .timeZone("America/Los_Angeles") // Change to your timezone
  .onRun(async (context) => {
    console.log("🔄 Starting recurring expense processing...");

    const today = new Date();
    const currentDay = today.getDate();
    const currentMonth = today.getMonth() + 1; // JavaScript months are 0-indexed
    const currentYear = today.getFullYear();

    console.log(
      `📅 Processing for: Day ${currentDay}, Month ${currentMonth}, Year ${currentYear}`
    );

    try {
      // Get all users
      const usersSnapshot = await db.collection("users").get();
      let totalProcessed = 0;
      let totalCreated = 0;

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        console.log(`👤 Processing user: ${userId}`);

        // Get all active recurring expenses for this user
        const recurringExpensesRef = db
          .collection("users")
          .doc(userId)
          .collection("recurringExpenses");

        const activeExpenses = await recurringExpensesRef
          .where("active", "==", true)
          .get();

        if (activeExpenses.empty) {
          console.log(`  ℹ️  No active recurring expenses for user ${userId}`);
          continue;
        }

        console.log(
          `  📋 Found ${activeExpenses.size} active recurring expenses`
        );

        for (const expenseDoc of activeExpenses.docs) {
          const expense = expenseDoc.data();
          const expenseId = expenseDoc.id;

          totalProcessed++;

          // Check if this expense should be charged today
          if (
            shouldCreateExpenseToday(
              expense,
              currentDay,
              currentMonth,
              currentYear
            )
          ) {
            console.log(
              `  ✅ Creating charge for: ${expense.name} (${expense.amount})`
            );

            try {
              // Create the expense
              const expenseRef = db
                .collection("users")
                .doc(userId)
                .collection("expenses");

              const newExpense = {
                amount: expense.amount,
                name: expense.name,
                category: expense.category,
                subcategory: expense.subcategory || null,
                date: formatISODate(today),
                paymentMethod: expense.paymentMethod,
                notes: `Cargo automático (${expense.frequency || "mensual"})`,
                isRecurring: true,
                recurring: true,
                recurringId: expenseId,
                recurringFrequency: expense.frequency || "monthly",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              };

              await expenseRef.add(newExpense);

              // Update lastCreated timestamp on recurring expense
              await recurringExpensesRef.doc(expenseId).update({
                lastCreated: formatISODate(today),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              totalCreated++;
              console.log(
                `  ✅ Successfully created expense for: ${expense.name}`
              );
            } catch (error) {
              console.error(
                `  ❌ Error creating expense for ${expense.name}:`,
                error
              );
            }
          } else {
            console.log(`  ⏭️  Skipping ${expense.name} - not due today`);
          }
        }
      }

      console.log(
        `✅ Processing complete: ${totalProcessed} expenses checked, ${totalCreated} created`
      );
      return { processed: totalProcessed, created: totalCreated };
    } catch (error) {
      console.error("❌ Error processing recurring expenses:", error);
      throw error;
    }
  });

/**
 * Helper function to determine if a recurring expense should be charged today
 *
 * @param {Object} expense - The recurring expense object
 * @param {number} currentDay - Current day of month (1-31)
 * @param {number} currentMonth - Current month (1-12)
 * @param {number} currentYear - Current year
 * @returns {boolean} - True if expense should be charged today
 */
function shouldCreateExpenseToday(
  expense,
  currentDay,
  currentMonth,
  currentYear
) {
  // Get frequency first (needed for checks)
  const frequency = expense.frequency || "monthly";

  // Check if day of month matches
  if (expense.dayOfMonth !== currentDay) {
    return false;
  }

  // Check if already created today (prevent duplicates)
  if (expense.lastCreated) {
    // Parse lastCreated as YYYY-MM-DD string (ISO format from Firestore)
    const lastCreatedStr = expense.lastCreated;
    const todayStr = formatISODate(
      new Date(currentYear, currentMonth - 1, currentDay)
    );

    console.log(
      `    🔍 Checking duplicate: lastCreated="${lastCreatedStr}", today="${todayStr}"`
    );

    if (lastCreatedStr === todayStr) {
      console.log(`    ℹ️  Already created today for: ${expense.name}`);
      return false;
    }

    // Additional check to prevent multiple charges in same month for ALL non-monthly frequencies
    if (frequency !== "monthly") {
      const lastCreatedParts = lastCreatedStr.split("-");
      if (lastCreatedParts.length === 3) {
        const lastYear = parseInt(lastCreatedParts[0]);
        const lastMonth = parseInt(lastCreatedParts[1]);

        // If already created this month this year, skip
        if (lastYear === currentYear && lastMonth === currentMonth) {
          console.log(
            `    ℹ️  ${frequency} expense already created this month (${lastCreatedStr}) for: ${expense.name}`
          );
          return false;
        }
      }
    }
  }

  // Validate based on frequency

  switch (frequency) {
    case "monthly":
      // Monthly expenses: charge every month on the specified day
      return true;

    case "quarterly":
      // Quarterly: charge every 3 months starting from billingMonth
      if (!expense.billingMonth) {
        console.warn(
          `    ⚠️  Quarterly expense ${expense.name} missing billingMonth`
        );
        return false;
      }
      // Check if current month is billingMonth, billingMonth+3, billingMonth+6, or billingMonth+9
      const quarterlyMonths = [
        expense.billingMonth,
        ((expense.billingMonth + 3 - 1) % 12) + 1,
        ((expense.billingMonth + 6 - 1) % 12) + 1,
        ((expense.billingMonth + 9 - 1) % 12) + 1,
      ];
      return quarterlyMonths.includes(currentMonth);

    case "semestral":
      // Semestral (biannual): charge every 6 months starting from billingMonth
      if (!expense.billingMonth) {
        console.warn(
          `    ⚠️  Semestral expense ${expense.name} missing billingMonth`
        );
        return false;
      }
      // Check if current month is billingMonth or billingMonth+6
      const semestralMonths = [
        expense.billingMonth,
        ((expense.billingMonth + 6 - 1) % 12) + 1,
      ];
      return semestralMonths.includes(currentMonth);

    case "yearly":
    case "annual":
      // Yearly: charge once per year in the specified month
      if (!expense.billingMonth) {
        console.warn(
          `    ⚠️  Yearly expense ${expense.name} missing billingMonth`
        );
        return false;
      }
      return currentMonth === expense.billingMonth;

    default:
      console.warn(
        `    ⚠️  Unknown frequency: ${frequency} for ${expense.name}`
      );
      return false;
  }
}

/**
 * Format date as ISO 8601 string (YYYY-MM-DD)
 *
 * @param {Date} date - Date to format
 * @returns {string} - ISO formatted date string
 */
function formatISODate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Manual trigger function for testing (HTTP callable)
 * Can be called from the app or Firebase console for testing
 */
exports.processRecurringExpensesManual = functions.https.onCall(
  async (data, context) => {
    // Require authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to trigger manual processing"
      );
    }

    console.log("🔧 Manual trigger by user:", context.auth.uid);

    // Call the same processing logic
    const result = await exports.processRecurringExpenses.run();
    return result;
  }
);
