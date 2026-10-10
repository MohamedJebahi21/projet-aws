package com.library.db;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class DBConnection {
    private static final Logger log = LoggerFactory.getLogger(DBConnection.class);
    private static HikariDataSource dataSource;

    public static synchronized void init() {
        if (dataSource != null && !dataSource.isClosed()) {
            return;
        }

        String host = System.getenv().getOrDefault("DB_HOST", "localhost");
        String port = System.getenv().getOrDefault("DB_PORT", "5432");
        String dbName = System.getenv().getOrDefault("DB_NAME", "library");
        String user = System.getenv().getOrDefault("DB_USER", "dbadmin");
        String password = System.getenv().getOrDefault("DB_PASSWORD", "SecretPass123!");

        String jdbcUrl = String.format("jdbc:postgresql://%s:%s/%s?sslmode=prefer&connectTimeout=5", host, port, dbName);
        log.info("Connexion PostgreSQL vers {} (utilisateur: {})", jdbcUrl, user);

        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(jdbcUrl);
        config.setUsername(user);
        config.setPassword(password);
        config.setDriverClassName("org.postgresql.Driver");
        config.setMaximumPoolSize(10);
        config.setMinimumIdle(2);
        config.setIdleTimeout(30000);
        config.setConnectionTimeout(10000);
        config.setMaxLifetime(600000);

        try {
            dataSource = new HikariDataSource(config);
            createSchemaIfNotExists();
            seedInitialData();
            log.info("Base de donnees PostgreSQL initialisee avec succes.");
        } catch (Exception e) {
            log.error("Erreur lors de l'initialisation du pool de base de donnees: {}", e.getMessage());
            // Ne pas arreter l'application, pour permettre au healthcheck de remonter l'erreur proprement
        }
    }

    public static Connection getConnection() throws SQLException {
        if (dataSource == null) {
            init();
        }
        if (dataSource == null) {
            throw new SQLException("Pool de connexions non initialise");
        }
        return dataSource.getConnection();
    }

    public static boolean checkHealth() {
        if (dataSource == null) {
            try { init(); } catch (Exception ignored) {}
        }
        if (dataSource == null) return false;
        try (Connection conn = dataSource.getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.setQueryTimeout(2);
            try (ResultSet rs = stmt.executeQuery("SELECT 1")) {
                return rs.next();
            }
        } catch (Exception e) {
            log.warn("Echec du health check base de donnees: {}", e.getMessage());
            return false;
        }
    }

    private static void createSchemaIfNotExists() {
        try (Connection conn = dataSource.getConnection();
             Statement stmt = conn.createStatement()) {
            
            // Schema relationnel PostgreSQL
            stmt.executeUpdate("CREATE TABLE IF NOT EXISTS books (" +
                    "id SERIAL PRIMARY KEY, " +
                    "title VARCHAR(255) NOT NULL, " +
                    "isbn VARCHAR(50) UNIQUE NOT NULL, " +
                    "author VARCHAR(255) NOT NULL, " +
                    "category VARCHAR(100) NOT NULL)");

            stmt.executeUpdate("CREATE TABLE IF NOT EXISTS members (" +
                    "id SERIAL PRIMARY KEY, " +
                    "name VARCHAR(255) NOT NULL, " +
                    "email VARCHAR(255) NOT NULL)");

            stmt.executeUpdate("CREATE TABLE IF NOT EXISTS copies (" +
                    "id SERIAL PRIMARY KEY, " +
                    "book_id INT NOT NULL REFERENCES books(id) ON DELETE CASCADE, " +
                    "status VARCHAR(50) NOT NULL DEFAULT 'AVAILABLE')");

            stmt.executeUpdate("CREATE TABLE IF NOT EXISTS loans (" +
                    "id SERIAL PRIMARY KEY, " +
                    "copy_id INT NOT NULL REFERENCES copies(id) ON DELETE CASCADE, " +
                    "member_id INT NOT NULL REFERENCES members(id) ON DELETE CASCADE, " +
                    "borrow_date DATE NOT NULL, " +
                    "due_date DATE NOT NULL, " +
                    "return_date DATE)");

            stmt.executeUpdate("CREATE TABLE IF NOT EXISTS penalties (" +
                    "id SERIAL PRIMARY KEY, " +
                    "member_id INT NOT NULL REFERENCES members(id) ON DELETE CASCADE, " +
                    "amount NUMERIC(10,2) NOT NULL, " +
                    "paid INT NOT NULL DEFAULT 0, " +
                    "description TEXT, " +
                    "loan_id INT DEFAULT 0)");

            log.info("Schema PostgreSQL verifie/cree avec succes.");
        } catch (Exception e) {
            log.error("Erreur lors de la creation des tables: {}", e.getMessage());
        }
    }

    private static void seedInitialData() {
        try (Connection conn = dataSource.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM books")) {
            if (rs.next() && rs.getInt(1) == 0) {
                log.info("Insertion du jeu de donnees initial dans PostgreSQL...");
                stmt.executeUpdate("INSERT INTO books(title, isbn, author, category) VALUES " +
                        "('Programmation Java Avancee', '978-0134685991', 'Joshua Bloch', 'Informatique')," +
                        "('Architectures Cloud & DevOps', '978-1491956250', 'Gene Kim', 'DevOps')," +
                        "('Bases de donnees relationnelles', '978-0133970777', 'Ramez Elmasri', 'Informatique')," +
                        "('Securite des systemes AWS', '978-1119561569', 'Ben Piper', 'Securite')");

                stmt.executeUpdate("INSERT INTO members(name, email) VALUES " +
                        "('Alice Martin', 'alice.martin@universite.fr')," +
                        "('Mohamed Lameri', 'm.lameri@universite.fr')," +
                        "('Thomas Dubois', 'thomas.dubois@universite.fr')");

                // Creer 2 exemplaires disponibles pour chaque livre
                stmt.executeUpdate("INSERT INTO copies(book_id, status) " +
                        "SELECT id, 'AVAILABLE' FROM books UNION ALL SELECT id, 'AVAILABLE' FROM books");

                // Creer un pret d'exemple (en cours) et un pret en retard
                stmt.executeUpdate("INSERT INTO loans(copy_id, member_id, borrow_date, due_date, return_date) VALUES " +
                        "(1, 1, CURRENT_DATE - INTERVAL '5 days', CURRENT_DATE + INTERVAL '9 days', NULL)," +
                        "(2, 2, CURRENT_DATE - INTERVAL '20 days', CURRENT_DATE - INTERVAL '6 days', NULL)");

                stmt.executeUpdate("UPDATE copies SET status = 'BORROWED' WHERE id IN (1, 2)");
                log.info("Donnees d'initialisation inserees.");
            }
        } catch (Exception e) {
            log.warn("Impossible de verifier ou inserer les donnees initiales: {}", e.getMessage());
        }
    }

    public static void close() {
        if (dataSource != null && !dataSource.isClosed()) {
            dataSource.close();
        }
    }
}
