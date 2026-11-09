import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/sistema_remote_datasource.dart';
import '../../data/repositories/sistema_repository_impl.dart';
import '../../domain/entities/estado_servicio.dart';
import '../../domain/repositories/sistema_repository.dart';
import '../../domain/usecases/consultar_estado_servicio.dart';

final sistemaRemoteDataSourceProvider = Provider<SistemaRemoteDataSource>(
  (ref) => SistemaRemoteDataSourceImpl(ref.watch(restClientProvider)),
);

final sistemaRepositoryProvider = Provider<SistemaRepository>(
  (ref) => SistemaRepositoryImpl(ref.watch(sistemaRemoteDataSourceProvider)),
);

final consultarEstadoServicioProvider = Provider<ConsultarEstadoServicio>(
  (ref) => ConsultarEstadoServicio(ref.watch(sistemaRepositoryProvider)),
);

final estadoServicioProvider = FutureProvider.autoDispose<EstadoServicio>(
  (ref) => ref.watch(consultarEstadoServicioProvider)(),
);
