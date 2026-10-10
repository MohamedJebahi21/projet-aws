# ========================================================
# ÉTAPE 1 : Compilation Multi-Stage avec Maven et Java 17
# ========================================================
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder
WORKDIR /build

# Mise en cache optimale des dépendances Maven
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Compilation et packaging de l'Uber-JAR
COPY src ./src
RUN mvn clean package -DskipTests -B

# ========================================================
# ÉTAPE 2 : Image d'Exécution Légère et Sécurisée (Alpine JRE)
# ========================================================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /opt/app

# Installation de curl pour le test de santé local
RUN apk --no-cache add curl

# Sécurité : Création d'un utilisateur non-root sans privilège
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copie de l'artefact compilé
COPY --from=builder /build/target/bibliotheque-app.jar app.jar
RUN chown -R appuser:appgroup /opt/app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
