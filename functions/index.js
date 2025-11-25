const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

// 🔔 Notificar al técnico cuando se le asigne un trabajo
exports.onRequestAssigned = functions.firestore
  .document("requests/{id}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Solo cuando pasa de 'pendiente' a 'asignada'
    if (before.estado === 'pendiente' && after.estado === 'asignada' && after.tecnicoAsignadoId) {
      const techId = after.tecnicoAsignadoId;
      const techDoc = await admin.firestore().doc(`users/${techId}`).get();
      const token = techDoc.get('fcmToken');
      if (!token) return;

      await admin.messaging().send({
        token,
        notification: {
          title: "Nuevo trabajo asignado",
          body: `${after.tipo} – ${after.direccion}`,
        },
        data: {
          requestId: change.after.id,
          tipo: after.tipo,
        },
      });

      console.log("📩 Notificación enviada al técnico:", techId);
    }
  });