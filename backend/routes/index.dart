import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  return Response.json(
    body: const {
      'service': 'ghanaclass-backend',
      'status': 'ok',
    },
  );
}
