class BadRequestException implements Exception {
  BadRequestException(this.message);
  final String message;

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ForbiddenException implements Exception {
  ForbiddenException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ConflictException implements Exception {
  ConflictException(this.message);
  final String message;

  @override
  String toString() => message;
}
