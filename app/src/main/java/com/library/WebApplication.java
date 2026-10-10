package com.library;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.library.db.DBConnection;
import com.library.model.Book;
import com.library.model.Member;
import com.library.service.InstanceMetadataService;
import com.library.service.LibraryService;
import io.javalin.Javalin;
import io.javalin.json.JavalinJackson;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

public class WebApplication {
    private static final Logger log = LoggerFactory.getLogger(WebApplication.class);

    public static void main(String[] args) {
        log.info("Demarrage du serveur Web de la Bibliotheque Universitaire...");

        // Initialisation de la base PostgreSQL
        DBConnection.init();

        LibraryService libraryService = new LibraryService();

        // Configuration ObjectMapper Jackson pour JSON
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());

        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));

        Javalin app = Javalin.create(config -> {
            config.jsonMapper(new JavalinJackson(objectMapper));
            config.staticFiles.add("/public");
            config.showJavalinBanner = false;
        });

        // -------------------------------------------------------------
        // Route de santé pour ALB Health Check (EXIGENCE STRICTE L4/L5)
        // -------------------------------------------------------------
        app.get("/health", ctx -> {
            boolean dbHealthy = DBConnection.checkHealth();
            Map<String, Object> health = new HashMap<>();
            health.put("status", dbHealthy ? "UP" : "DOWN");
            health.put("database", dbHealthy ? "CONNECTED" : "UNREACHABLE");
            health.put("timestamp", Instant.now().toString());
            health.putAll(InstanceMetadataService.getMetadata());

            if (dbHealthy) {
                ctx.status(200).json(health);
            } else {
                ctx.status(503).json(health);
            }
        });

        // -------------------------------------------------------------
        // Metadonnees de l'instance (Demonstration repartition multi-AZ)
        // -------------------------------------------------------------
        app.get("/api/info", ctx -> {
            Map<String, Object> info = new HashMap<>();
            info.put("app", "Bibliotheque Universitaire AWS 3-Tiers");
            info.put("version", "1.0.0");
            info.put("time", Instant.now().toString());
            info.putAll(InstanceMetadataService.getMetadata());
            ctx.json(info);
        });

        // -------------------------------------------------------------
        // Statistiques globales
        // -------------------------------------------------------------
        app.get("/api/stats", ctx -> ctx.json(libraryService.getStats()));

        // -------------------------------------------------------------
        // Gestion des Livres
        // -------------------------------------------------------------
        app.get("/api/books", ctx -> {
            String query = ctx.queryParam("q");
            ctx.json(libraryService.getBooks(query));
        });

        app.post("/api/books", ctx -> {
            try {
                Book book = ctx.bodyAsClass(Book.class);
                if (book.getTitle() == null || book.getTitle().trim().isEmpty()) {
                    ctx.status(400).result("Le titre du livre est obligatoire");
                    return;
                }
                Book created = libraryService.addBook(book);
                ctx.status(201).json(created);
            } catch (Exception e) {
                log.error("Erreur ajout livre: {}", e.getMessage());
                ctx.status(500).result("Erreur: " + e.getMessage());
            }
        });

        // -------------------------------------------------------------
        // Gestion des Adhérents
        // -------------------------------------------------------------
        app.get("/api/members", ctx -> ctx.json(libraryService.getMembers()));

        app.post("/api/members", ctx -> {
            try {
                Member member = ctx.bodyAsClass(Member.class);
                if (member.getName() == null || member.getName().trim().isEmpty()) {
                    ctx.status(400).result("Le nom de l'adherent est obligatoire");
                    return;
                }
                Member created = libraryService.addMember(member);
                ctx.status(201).json(created);
            } catch (Exception e) {
                log.error("Erreur ajout adherent: {}", e.getMessage());
                ctx.status(500).result("Erreur: " + e.getMessage());
            }
        });

        // -------------------------------------------------------------
        // Gestion des Prêts et Retours
        // -------------------------------------------------------------
        app.get("/api/loans", ctx -> ctx.json(libraryService.getLoans(false)));

        app.get("/api/loans/overdue", ctx -> ctx.json(libraryService.getLoans(true)));

        app.post("/api/loans", ctx -> {
            try {
                Map<?, ?> body = ctx.bodyAsClass(Map.class);
                int bookId = Integer.parseInt(body.get("bookId").toString());
                int memberId = Integer.parseInt(body.get("memberId").toString());
                int days = body.containsKey("days") ? Integer.parseInt(body.get("days").toString()) : 14;

                Map<String, Object> result = libraryService.createLoan(bookId, memberId, days);
                ctx.status(201).json(result);
            } catch (IllegalStateException e) {
                ctx.status(409).result(e.getMessage());
            } catch (Exception e) {
                log.error("Erreur creation pret: {}", e.getMessage());
                ctx.status(500).result("Erreur: " + e.getMessage());
            }
        });

        app.post("/api/loans/{id}/return", ctx -> {
            try {
                int loanId = Integer.parseInt(ctx.pathParam("id"));
                Map<String, Object> result = libraryService.returnLoan(loanId);
                ctx.json(result);
            } catch (IllegalStateException e) {
                ctx.status(404).result(e.getMessage());
            } catch (Exception e) {
                log.error("Erreur retour pret: {}", e.getMessage());
                ctx.status(500).result("Erreur: " + e.getMessage());
            }
        });

        // Gestion de l'arret propre
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            log.info("Arret du serveur Web...");
            app.stop();
            DBConnection.close();
        }));

        app.start(port);
        log.info("Application web demarree et a l'ecoute sur le port {}", port);
    }
}
