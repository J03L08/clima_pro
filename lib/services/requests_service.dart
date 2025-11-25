import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clima_pro/models/solicitud.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class RequestsService {
  RequestsService._();
  static final RequestsService instance = RequestsService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('requests');

  // ======================================================================
  // createSolicitud
  // ======================================================================
  Future<String> createSolicitud({
    required String clienteId,
    required String tipo,
    required String descripcion,
    required String direccion,
    double? latitud,
    double? longitud,
    DateTime? fechaPreferida,
  }) async {
    final now = DateTime.now();

    final solicitudJson = <String, dynamic>{
      'clienteId': clienteId,
      'tipo': tipo,
      'descripcion': descripcion,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'fechaPreferida':
          fechaPreferida?.toIso8601String(),
      'estado': 'pendiente',
      'tecnicoAsignadoId': null,
      'ocultaCliente': false,
      'ratingCliente': null,
      'comentarioCliente': null,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    // ------------------ WEB: enviar mediante API local ------------------
    if (kIsWeb) {
      try {
        final uri = Uri.parse('http://localhost:4000/api/solicitudes');
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(solicitudJson),
        );

        // Si quisieras usar el id devuelto:
        // final json = jsonDecode(resp.body);
        // return json['id'] ?? '';

        return ''; // No necesitas el ID en web, lo gestionará SW/sync
      } catch (e) {
        return '';
      }
    }

    // ------------------ MÓVIL / ESCRITORIO: guardar directo en Firestore ------------------
    final ref = await _col.add({
      'clienteId': clienteId,
      'tipo': tipo,
      'descripcion': descripcion,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'fechaPreferida':
          fechaPreferida != null ? Timestamp.fromDate(fechaPreferida) : null,
      'estado': 'pendiente',
      'tecnicoAsignadoId': null,
      'ocultaCliente': false,
      'ratingCliente': null,
      'comentarioCliente': null,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return ref.id;
  }

  // ======================================================================
  // Streams
  // ======================================================================
  Stream<List<Solicitud>> mySolicitudes(String clienteId) {
    return _col
        .where('clienteId', isEqualTo: clienteId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Solicitud.fromDoc(d)).toList());
  }

  Stream<List<Solicitud>> todasDesc() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Solicitud.fromDoc(d)).toList());
  }

  Stream<List<Solicitud>> pendientesParaTecnico() {
    return _col
        .where('estado', isEqualTo: 'pendiente')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Solicitud.fromDoc(d)).toList());
  }

  Stream<List<Solicitud>> misTrabajos(String tecnicoId) {
    return _col
        .where('tecnicoAsignadoId', isEqualTo: tecnicoId)
        .where('estado', whereIn: ['asignada', 'en_proceso'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Solicitud.fromDoc(d)).toList());
  }

  // ======================================================================
  // Acciones del cliente
  // ======================================================================
  Future<void> cancelSolicitud(String id, String byUserId) async {
    await _col.doc(id).update({
      'estado': 'cancelada',
      'canceladaPor': byUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelSolicitudCliente(String id) async {
    await _col.doc(id).update({
      'estado': 'cancelada',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reprogramarSolicitud(String id, DateTime nuevaFecha) async {
    await _col.doc(id).update({
      'fechaPreferida': Timestamp.fromDate(nuevaFecha),
      'estado': 'pendiente',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ocultarSolicitudCliente(String id) async {
    await _col.doc(id).update({
      'ocultaCliente': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> guardarOpinionCliente(
      String id, int rating, String comentario) async {
    await _col.doc(id).update({
      'ratingCliente': rating,
      'comentarioCliente': comentario,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ======================================================================
  // Acciones del técnico
  // ======================================================================
  Future<void> asignarme(String requestId, String tecnicoId) async {
    await _col.doc(requestId).update({
      'estado': 'asignada',
      'tecnicoAsignadoId': tecnicoId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> iniciarTrabajo(String requestId, String tecnicoId) async {
    await _col.doc(requestId).update({
      'estado': 'en_proceso',
      'tecnicoAsignadoId': tecnicoId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completar(String requestId, String tecnicoId) async {
    await _col.doc(requestId).update({
      'estado': 'completada',
      'tecnicoAsignadoId': tecnicoId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ======================================================================
  // Acciones del admin
  // ======================================================================
  Future<void> adminAsignar(String requestId, String tecnicoId) async {
    await _col.doc(requestId).update({
      'estado': 'asignada',
      'tecnicoAsignadoId': tecnicoId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminCambiarEstado(String requestId, String estado) async {
    await _col.doc(requestId).update({
      'estado': estado,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}