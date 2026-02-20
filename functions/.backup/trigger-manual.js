/**
 * Trigger manual de processRecurringExpenses
 * Ejecutar con: node trigger-manual.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Inicializar admin solo si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function triggerProcessing() {
  console.log('🔄 Ejecutando processRecurringExpenses manualmente...\n');

  const today = new Date();
  const currentDay = today.getDate();
  const currentMonth = today.getMonth() + 1;
  const currentYear = today.getFullYear();

  console.log(`📅 Fecha actual: ${currentDay}/${currentMonth}/${currentYear}\n`);

  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    let totalProcessed = 0;
    let totalCreated = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      console.log(`👤 Procesando usuario: ${userId}`);

      // Get all active recurring expenses for this user
      const recurringExpensesRef = db
        .collection('users')
        .doc(userId)
        .collection('recurringExpenses');

      const activeExpenses = await recurringExpensesRef
        .where('active', '==', true)
        .get();

      if (activeExpenses.empty) {
        console.log(`  ℹ️  No hay gastos recurrentes activos\n`);
        continue;
      }

      console.log(`  📋 Encontrados ${activeExpenses.size} gastos recurrentes activos`);

      for (const expenseDoc of activeExpenses.docs) {
        const expense = expenseDoc.data();
        const expenseId = expenseDoc.id;
        totalProcessed++;

        // Check if should create today
        if (shouldCreateExpenseToday(expense, currentDay, currentMonth, currentYear)) {
          console.log(`  ✅ Creando gasto: ${expense.name} (${expense.amount}€)`);

          try {
            const expenseRef = db
              .collection('users')
              .doc(userId)
              .collection('expenses');

            const newExpense = {
              amount: expense.amount,
              name: expense.name,
              category: expense.category,
              subcategory: expense.subcategory || null,
              date: formatISODate(today),
              paymentMethod: expense.paymentMethod,
              notes: 'Cargo automático de gasto recurrente',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };

            await expenseRef.add(newExpense);

            // Update lastCreated
            await recurringExpensesRef.doc(expenseId).update({
              lastCreated: formatISODate(today),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            totalCreated++;
          } catch (error) {
            console.error(`  ❌ Error creando gasto ${expense.name}:`, error);
          }
        } else {
          console.log(`  ⏭️  Saltando: ${expense.name} (no corresponde hoy)`);
        }
      }

      console.log(''); // Blank line
    }

    console.log(`\n✅ Procesamiento completado`);
    console.log(`📊 Resultados:`);
    console.log(`   - Gastos procesados: ${totalProcessed}`);
    console.log(`   - Gastos creados: ${totalCreated}`);

  } catch (error) {
    console.error('❌ Error en procesamiento:', error);
  }

  process.exit(0);
}

// Helper functions (copiadas de index.js)
function shouldCreateExpenseToday(expense, currentDay, currentMonth, currentYear) {
  const frequency = expense.frequency || 'monthly';

  if (expense.dayOfMonth !== currentDay) {
    return false;
  }

  if (expense.lastCreated) {
    const lastCreatedStr = expense.lastCreated;
    const todayStr = formatISODate(new Date(currentYear, currentMonth - 1, currentDay));

    console.log(`    🔍 Verificando duplicado: lastCreated="${lastCreatedStr}", hoy="${todayStr}"`);

    if (lastCreatedStr === todayStr) {
      console.log(`    ℹ️  Ya creado hoy: ${expense.name}`);
      return false;
    }

    if (frequency !== 'monthly') {
      const lastCreatedParts = lastCreatedStr.split('-');
      if (lastCreatedParts.length === 3) {
        const lastYear = parseInt(lastCreatedParts[0]);
        const lastMonth = parseInt(lastCreatedParts[1]);

        if (lastYear === currentYear && lastMonth === currentMonth) {
          console.log(`    ℹ️  ${frequency} ya creado este mes (${lastCreatedStr}): ${expense.name}`);
          return false;
        }
      }
    }
  }

  switch (frequency) {
    case 'monthly':
      return true;

    case 'quarterly':
      if (!expense.billingMonth) return false;
      const quarterlyMonths = [
        expense.billingMonth,
        (expense.billingMonth + 3 - 1) % 12 + 1,
        (expense.billingMonth + 6 - 1) % 12 + 1,
        (expense.billingMonth + 9 - 1) % 12 + 1
      ];
      return quarterlyMonths.includes(currentMonth);

    case 'semestral':
      if (!expense.billingMonth) return false;
      const semestralMonths = [
        expense.billingMonth,
        (expense.billingMonth + 6 - 1) % 12 + 1
      ];
      return semestralMonths.includes(currentMonth);

    case 'yearly':
    case 'annual':
      if (!expense.billingMonth) return false;
      return currentMonth === expense.billingMonth;

    default:
      return false;
  }
}

function formatISODate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

triggerProcessing();
