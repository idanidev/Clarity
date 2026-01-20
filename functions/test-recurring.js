/**
 * Script de prueba para gastos recurrentes
 * Ejecutar con: node test-recurring.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json"); // Necesitarás este archivo

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// User ID del primer usuario encontrado en Firestore
const TEST_USER_ID = "7NvmEzIRDYaRSh5oHsY9TR88M3w1";

async function createTestRecurringExpenses() {
  console.log("🧪 Creando gastos recurrentes de prueba...\n");

  const recurringExpensesRef = db
    .collection("users")
    .doc(TEST_USER_ID)
    .collection("recurringExpenses");

  // 1. MENSUAL - Se cobra cada mes el día 5
  const monthly = {
    name: "Netflix (Test Mensual)",
    amount: 15.99,
    category: "📺 Entretenimiento",
    subcategory: "Streaming",
    frequency: "monthly",
    dayOfMonth: 17, // Hoy es 17 de enero
    active: true,
    paymentMethod: "Tarjeta",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // 2. TRIMESTRAL - Se cobra cada 3 meses el día 15
  const quarterly = {
    name: "Seguro Trimestral (Test)",
    amount: 250.0,
    category: "🏡 Vivienda",
    subcategory: "Seguros",
    frequency: "quarterly",
    billingMonth: 1, // Enero (luego abril, julio, octubre)
    dayOfMonth: 17,
    active: true,
    paymentMethod: "Transferencia",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // 3. SEMESTRAL - Se cobra cada 6 meses el día 20
  const semestral = {
    name: "IBI Semestral (Test)",
    amount: 450.0,
    category: "🏡 Vivienda",
    subcategory: "Impuestos",
    frequency: "semestral",
    billingMonth: 1, // Enero (luego julio)
    dayOfMonth: 17,
    active: true,
    paymentMethod: "Domiciliación",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // 4. ANUAL - Se cobra una vez al año el día 25
  const yearly = {
    name: "Seguro Hogar Anual (Test)",
    amount: 850.0,
    category: "🏡 Vivienda",
    subcategory: "Seguros",
    frequency: "yearly",
    billingMonth: 1, // Solo en enero
    dayOfMonth: 17,
    active: true,
    paymentMethod: "Tarjeta",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // 5. MENSUAL (DÍA 1) - Para probar el principio del mes
  const monthlyDay1 = {
    name: "Alquiler (Test Mensual Día 1)",
    amount: 800.0,
    category: "🏡 Vivienda",
    subcategory: "Alquiler",
    frequency: "monthly",
    dayOfMonth: 1,
    active: true,
    paymentMethod: "Transferencia",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // 6. MENSUAL (DÍA 31) - Para probar fin de mes
  const monthlyDay31 = {
    name: "Gimnasio (Test Mensual Día 31)",
    amount: 45.0,
    category: "🏥 Salud",
    subcategory: "Deporte",
    frequency: "monthly",
    dayOfMonth: 31,
    active: true,
    paymentMethod: "Tarjeta",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    await recurringExpensesRef.add(monthly);
    console.log("✅ Mensual creado: Netflix (día 17)");

    await recurringExpensesRef.add(quarterly);
    console.log(
      "✅ Trimestral creado: Seguro (enero/abril/julio/octubre, día 17)"
    );

    await recurringExpensesRef.add(semestral);
    console.log("✅ Semestral creado: IBI (enero/julio, día 17)");

    await recurringExpensesRef.add(yearly);
    console.log("✅ Anual creado: Seguro Hogar (solo enero, día 17)");

    await recurringExpensesRef.add(monthlyDay1);
    console.log("✅ Mensual creado: Alquiler (día 1)");

    await recurringExpensesRef.add(monthlyDay31);
    console.log("✅ Mensual creado: Gimnasio (día 31)");

    console.log(
      "\n🎉 Todos los gastos recurrentes de prueba creados correctamente\n"
    );
    console.log("📋 Resumen:");
    console.log("   - 3 gastos mensuales (días 1, 17, 31)");
    console.log("   - 1 gasto trimestral (cada 3 meses, día 17)");
    console.log("   - 1 gasto semestral (cada 6 meses, día 17)");
    console.log("   - 1 gasto anual (una vez al año, día 17)");
    console.log(
      "\n💡 Ejecuta la función processRecurringExpenses para probarlos\n"
    );
  } catch (error) {
    console.error("❌ Error creando gastos de prueba:", error);
  }

  process.exit(0);
}

async function testProcessingLogic() {
  console.log("🧪 TESTS EXHAUSTIVOS - Lógica de gastos recurrentes\n");
  console.log("═".repeat(60) + "\n");

  let passed = 0;
  let failed = 0;

  const testCases = [
    // ═══════════════════════════════════════════════════════════
    // MENSUALES - Casos básicos
    // ═══════════════════════════════════════════════════════════
    {
      name: "📅 MENSUAL: Día coincide exacto",
      expense: { frequency: "monthly", dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "📅 MENSUAL: Día NO coincide",
      expense: { frequency: "monthly", dayOfMonth: 15 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "📅 MENSUAL: Día 1 del mes",
      expense: { frequency: "monthly", dayOfMonth: 1 },
      currentDay: 1,
      currentMonth: 3,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "📅 MENSUAL: Día 31 (fin de mes)",
      expense: { frequency: "monthly", dayOfMonth: 31 },
      currentDay: 31,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },

    // ═══════════════════════════════════════════════════════════
    // PREVENCIÓN DE DUPLICADOS - lastCreated
    // ═══════════════════════════════════════════════════════════
    {
      name: "🚫 DUPLICADO: Ya cobrado HOY mismo",
      expense: {
        frequency: "monthly",
        dayOfMonth: 17,
        lastCreated: "2026-01-17",
      },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "✅ NO DUPLICADO: Cobrado AYER",
      expense: {
        frequency: "monthly",
        dayOfMonth: 17,
        lastCreated: "2025-12-17",
      },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "🚫 TRIMESTRAL: Ya cobrado ESTE MES (no debe repetir)",
      expense: {
        frequency: "quarterly",
        billingMonth: 1,
        dayOfMonth: 17,
        lastCreated: "2026-01-05",
      },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "✅ TRIMESTRAL: Cobrado hace 3 meses (OK repetir)",
      expense: {
        frequency: "quarterly",
        billingMonth: 1,
        dayOfMonth: 17,
        lastCreated: "2025-10-17",
      },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },

    // ═══════════════════════════════════════════════════════════
    // ANUALES
    // ═══════════════════════════════════════════════════════════
    {
      name: "📆 ANUAL: Mes y día correctos",
      expense: { frequency: "yearly", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "📆 ANUAL: Mes incorrecto",
      expense: { frequency: "yearly", billingMonth: 6, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "📆 ANUAL: Día incorrecto aunque mes OK",
      expense: { frequency: "yearly", billingMonth: 1, dayOfMonth: 20 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "📆 ANUAL: Sin billingMonth (debe fallar)",
      expense: { frequency: "yearly", dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },

    // ═══════════════════════════════════════════════════════════
    // TRIMESTRALES - Todos los ciclos
    // ═══════════════════════════════════════════════════════════
    {
      name: "🔄 TRIMESTRAL: Mes base (enero)",
      expense: { frequency: "quarterly", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "🔄 TRIMESTRAL: Mes +3 (abril)",
      expense: { frequency: "quarterly", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 4,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "🔄 TRIMESTRAL: Mes +6 (julio)",
      expense: { frequency: "quarterly", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 7,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "🔄 TRIMESTRAL: Mes +9 (octubre)",
      expense: { frequency: "quarterly", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 10,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "🔄 TRIMESTRAL: Mes intermedio (febrero) - NO debe cobrar",
      expense: { frequency: "quarterly", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 2,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "🔄 TRIMESTRAL: Sin billingMonth (debe fallar)",
      expense: { frequency: "quarterly", dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },

    // ═══════════════════════════════════════════════════════════
    // SEMESTRALES
    // ═══════════════════════════════════════════════════════════
    {
      name: "🔁 SEMESTRAL: Mes base (enero)",
      expense: { frequency: "semestral", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "🔁 SEMESTRAL: Mes +6 (julio)",
      expense: { frequency: "semestral", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 7,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "🔁 SEMESTRAL: Mes intermedio (abril) - NO debe cobrar",
      expense: { frequency: "semestral", billingMonth: 1, dayOfMonth: 17 },
      currentDay: 17,
      currentMonth: 4,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "🔁 SEMESTRAL: Wrap around (julio base → enero)",
      expense: { frequency: "semestral", billingMonth: 7, dayOfMonth: 15 },
      currentDay: 15,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },

    // ═══════════════════════════════════════════════════════════
    // EDGE CASES CRÍTICOS
    // ═══════════════════════════════════════════════════════════
    {
      name: "⚠️ EDGE: Frecuencia desconocida",
      expense: { frequency: "semanal", dayOfMonth: 17 }, // no soportada
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "⚠️ EDGE: Sin frecuencia (default monthly)",
      expense: { dayOfMonth: 17 }, // sin frequency
      currentDay: 17,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "⚠️ EDGE: Cambio de año (dic→ene)",
      expense: {
        frequency: "monthly",
        dayOfMonth: 1,
        lastCreated: "2025-12-01",
      },
      currentDay: 1,
      currentMonth: 1,
      currentYear: 2026,
      expected: true,
    },
    {
      name: '⚠️ EDGE: Alias "annual" = "yearly"',
      expense: { frequency: "annual", billingMonth: 3, dayOfMonth: 10 },
      currentDay: 10,
      currentMonth: 3,
      currentYear: 2026,
      expected: true,
    },

    // ═══════════════════════════════════════════════════════════
    // ESCENARIOS DE PRODUCCIÓN REALES
    // ═══════════════════════════════════════════════════════════
    {
      name: "🏠 REAL: Alquiler día 1 de cada mes",
      expense: {
        name: "Alquiler",
        frequency: "monthly",
        dayOfMonth: 1,
        amount: 800,
      },
      currentDay: 1,
      currentMonth: 6,
      currentYear: 2026,
      expected: true,
    },
    {
      name: "📺 REAL: Netflix ya cobrado este mes",
      expense: {
        name: "Netflix",
        frequency: "monthly",
        dayOfMonth: 15,
        lastCreated: "2026-01-15",
      },
      currentDay: 15,
      currentMonth: 1,
      currentYear: 2026,
      expected: false,
    },
    {
      name: "🚗 REAL: Seguro auto trimestral",
      expense: {
        name: "Seguro Auto",
        frequency: "quarterly",
        billingMonth: 3,
        dayOfMonth: 5,
      },
      currentDay: 5,
      currentMonth: 9,
      currentYear: 2026, // marzo+6
      expected: true,
    },
  ];

  console.log("Ejecutando " + testCases.length + " tests...\n");

  testCases.forEach((test, index) => {
    const result = shouldCreateExpenseToday(
      test.expense,
      test.currentDay,
      test.currentMonth,
      test.currentYear
    );
    const pass = result === test.expected;

    if (pass) {
      passed++;
      console.log(`✅ #${String(index + 1).padStart(2, "0")} ${test.name}`);
    } else {
      failed++;
      console.log(`❌ #${String(index + 1).padStart(2, "0")} ${test.name}`);
      console.log(`      Esperado: ${test.expected}, Recibido: ${result}`);
    }
  });

  console.log("\n" + "═".repeat(60));
  console.log(`\n📊 RESULTADOS: ${passed}/${testCases.length} tests pasados`);

  if (failed > 0) {
    console.log(
      `❌ ${failed} tests FALLARON - ¡REVISAR ANTES DE PRODUCCIÓN!\n`
    );
    process.exit(1);
  } else {
    console.log("✅ TODOS LOS TESTS PASARON - Listo para producción 🚀\n");
    process.exit(0);
  }
}

// Copia de la función del index.js para testing
function shouldCreateExpenseToday(
  expense,
  currentDay,
  currentMonth,
  currentYear
) {
  const frequency = expense.frequency || "monthly";

  if (expense.dayOfMonth !== currentDay) {
    return false;
  }

  if (expense.lastCreated) {
    const lastCreatedStr = expense.lastCreated;
    const todayStr = formatISODate(
      new Date(currentYear, currentMonth - 1, currentDay)
    );

    if (lastCreatedStr === todayStr) {
      return false;
    }

    if (frequency !== "monthly") {
      const lastCreatedParts = lastCreatedStr.split("-");
      if (lastCreatedParts.length === 3) {
        const lastYear = parseInt(lastCreatedParts[0]);
        const lastMonth = parseInt(lastCreatedParts[1]);

        if (lastYear === currentYear && lastMonth === currentMonth) {
          return false;
        }
      }
    }
  }

  switch (frequency) {
    case "monthly":
      return true;

    case "quarterly":
      if (!expense.billingMonth) return false;
      const quarterlyMonths = [
        expense.billingMonth,
        ((expense.billingMonth + 3 - 1) % 12) + 1,
        ((expense.billingMonth + 6 - 1) % 12) + 1,
        ((expense.billingMonth + 9 - 1) % 12) + 1,
      ];
      return quarterlyMonths.includes(currentMonth);

    case "semestral":
      if (!expense.billingMonth) return false;
      const semestralMonths = [
        expense.billingMonth,
        ((expense.billingMonth + 6 - 1) % 12) + 1,
      ];
      return semestralMonths.includes(currentMonth);

    case "yearly":
    case "annual":
      if (!expense.billingMonth) return false;
      return currentMonth === expense.billingMonth;

    default:
      return false;
  }
}

function formatISODate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

// Ejecutar según el argumento
const mode = process.argv[2];

if (mode === "create") {
  createTestRecurringExpenses();
} else if (mode === "test") {
  testProcessingLogic();
} else {
  console.log("📚 Uso:");
  console.log(
    "  node test-recurring.js create  - Crear gastos de prueba en Firestore"
  );
  console.log(
    "  node test-recurring.js test    - Probar lógica sin tocar Firestore"
  );
  process.exit(0);
}
