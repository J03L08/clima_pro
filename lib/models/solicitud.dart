import 'package:cloud_firestore/cloud_firestore.dart';

class Solicitud {
  final String id;
  final String clienteId;
  final String tipo;
  final String descripcion;
  final String direccion;

  final bool? ocultaCliente;

  final double? latitud;
  final double? longitud;

  final DateTime? fechaPreferida;
  final String estado;
  final String? tecnicoAsignadoId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Solicitud({
    required this.id,
    required this.clienteId,
    required this.tipo,
    required this.descripcion,
    required this.direccion,
    this.ocultaCliente,
    this.latitud,
    this.longitud,
    required this.fechaPreferida,
    required this.estado,
    this.tecnicoAsignadoId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'clienteId': clienteId,
        'tipo': tipo,
        'descripcion': descripcion,
        'direccion': direccion,

        'ocultaCliente': ocultaCliente,

        'latitud': latitud,
        'longitud': longitud,

        'fechaPreferida': fechaPreferida != null
            ? Timestamp.fromDate(fechaPreferida!)
            : null,
        'estado': estado,
        'tecnicoAsignadoId': tecnicoAsignadoId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory Solicitud.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};

    return Solicitud(
      id: doc.id,
      clienteId: d['clienteId'] as String? ?? '',
      tipo: d['tipo'] as String? ?? '',
      descripcion: d['descripcion'] as String? ?? '',
      direccion: d['direccion'] as String? ?? '',

      ocultaCliente: d['ocultaCliente'] as bool?,

      latitud: (d['latitud'] as num?)?.toDouble(),
      longitud: (d['longitud'] as num?)?.toDouble(),

      fechaPreferida: (d['fechaPreferida'] as Timestamp?)?.toDate(),
      estado: d['estado'] as String? ?? 'pendiente',
      tecnicoAsignadoId: d['tecnicoAsignadoId'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}