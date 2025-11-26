const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const app = express();
app.use(cors());
app.use(express.json());

// -----------------------
// POST /api/solicitudes
// -----------------------
app.post('/api/solicitudes', async (req, res) => {
  try {
    const body = req.body;
    console.log('Solicitud recibida en backend:', body);

    const now = new Date();

    const data = {
      clienteId: body.clienteId,
      tipo: body.tipo,
      descripcion: body.descripcion,
      direccion: body.direccion,
      latitud: body.latitud ?? null,
      longitud: body.longitud ?? null,
      fechaPreferida: body.fechaPreferida
        ? admin.firestore.Timestamp.fromDate(new Date(body.fechaPreferida))
        : null,
      estado: 'pendiente',
      tecnicoAsignadoId: null,
      ocultaCliente: false,
      ratingCliente: null,
      comentarioCliente: null,
      createdAt: admin.firestore.Timestamp.fromDate(
        body.createdAt ? new Date(body.createdAt) : now
      ),
      updatedAt: admin.firestore.Timestamp.fromDate(now),
    };

    const ref = await db.collection('requests').add(data);

    console.log('Solicitud guardada en Firestore con id:', ref.id);

    return res.status(200).json({
      ok: true,
      id: ref.id,
    });
  } catch (e) {
    console.error('Error en /api/solicitudes:', e);
    return res.status(500).json({
      ok: false,
      error: e.message || 'Error interno',
    });
  }
});

// Puerto del backend (puedes cambiarlo si quieres)
const PORT = 4000;
app.listen(PORT, () => {
  console.log(`ClimaPro backend escuchando en http://localhost:${PORT}`);
});
