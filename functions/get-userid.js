/**
 * Script para obtener el User ID del primer usuario en Firestore
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function getUserId() {
  console.log('🔍 Buscando usuarios en Firestore...\n');

  try {
    const usersSnapshot = await db.collection('users').limit(5).get();

    if (usersSnapshot.empty) {
      console.log('❌ No hay usuarios en Firestore');
      process.exit(1);
    }

    console.log(`✅ Encontrados ${usersSnapshot.size} usuarios:\n`);

    usersSnapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`${index + 1}. User ID: ${doc.id}`);
      console.log(`   Email: ${data.email || 'N/A'}`);
      console.log(`   Nombre: ${data.name || 'N/A'}`);
      console.log('');
    });

    const firstUserId = usersSnapshot.docs[0].id;
    console.log(`💡 Tu User ID (para usar en test-recurring.js):\n`);
    console.log(`   ${firstUserId}\n`);

  } catch (error) {
    console.error('❌ Error obteniendo usuarios:', error);
  }

  process.exit(0);
}

getUserId();
