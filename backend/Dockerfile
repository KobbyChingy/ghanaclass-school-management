FROM dart:stable AS build
WORKDIR /app

COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline

# Build the dart_frog production server (outputs to build/)
RUN dart run dart_frog_cli:dart_frog build

FROM dart:stable
WORKDIR /app

COPY --from=build /root/.pub-cache /root/.pub-cache
# Copy the backend sources needed for runtime migrations.
COPY --from=build /app /app

# Replace the dev server entrypoint with the compiled production server build.
COPY --from=build /app/build/bin/server.dart /app/bin/server.dart

RUN dart pub get --offline

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "dart run bin/migrate.dart && dart bin/server.dart"]
