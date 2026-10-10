package com.library.service;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.ByteArrayOutputStream;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class S3ReceiptService {
    private static final Logger log = LoggerFactory.getLogger(S3ReceiptService.class);
    private static final String BUCKET_NAME = System.getenv("S3_BUCKET_NAME");
    private static S3Client s3Client;

    private static synchronized S3Client getS3Client() {
        if (s3Client == null) {
            try {
                String region = System.getenv().getOrDefault("AWS_REGION", "us-east-1");
                s3Client = S3Client.builder()
                        .region(Region.of(region))
                        .build();
            } catch (Exception e) {
                log.warn("Impossible d'initialiser le client S3 (environnement local ou credentials absents): {}", e.getMessage());
            }
        }
        return s3Client;
    }

    public static String generateAndUploadReceipt(int loanId, String memberName, String bookTitle, String action) {
        try {
            // 1. Generation PDF en memoire (mode headless, sans GUI)
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            try (PDDocument doc = new PDDocument()) {
                PDPage page = new PDPage();
                doc.addPage(page);

                try (PDPageContentStream stream = new PDPageContentStream(doc, page)) {
                    stream.beginText();
                    stream.setFont(PDType1Font.HELVETICA_BOLD, 18);
                    stream.newLineAtOffset(50, 720);
                    stream.showText("BIBLIOTHEQUE UNIVERSITAIRE - RECU OFFICIEL");

                    stream.setFont(PDType1Font.HELVETICA, 12);
                    stream.newLineAtOffset(0, -30);
                    stream.showText("Type d'operation : " + action);

                    stream.newLineAtOffset(0, -20);
                    stream.showText("Numero de pret   : #" + loanId);

                    stream.newLineAtOffset(0, -20);
                    stream.showText("Adherent         : " + memberName);

                    stream.newLineAtOffset(0, -20);
                    stream.showText("Ouvrage          : " + bookTitle);

                    stream.newLineAtOffset(0, -20);
                    String date = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss"));
                    stream.showText("Date d'emission  : " + date);

                    stream.newLineAtOffset(0, -30);
                    stream.setFont(PDType1Font.HELVETICA_OBLIQUE, 10);
                    stream.showText("Ce document est genere automatiquement et archive de maniere securisee dans Amazon S3.");
                    stream.endText();
                }
                doc.save(out);
            }

            byte[] pdfBytes = out.toByteArray();
            String key = String.format("recus/%s-pret-%d-%d.pdf", action.toLowerCase(), loanId, System.currentTimeMillis());

            // 2. Upload vers Amazon S3 si le bucket est configure
            if (BUCKET_NAME != null && !BUCKET_NAME.trim().isEmpty()) {
                S3Client client = getS3Client();
                if (client != null) {
                    PutObjectRequest putReq = PutObjectRequest.builder()
                            .bucket(BUCKET_NAME)
                            .key(key)
                            .contentType("application/pdf")
                            .build();

                    client.putObject(putReq, RequestBody.fromBytes(pdfBytes));
                    log.info("Recu PDF televerse avec succes dans S3: s3://{}/{}", BUCKET_NAME, key);
                    return "s3://" + BUCKET_NAME + "/" + key;
                }
            }

            log.info("Recu PDF genere en local (taille: {} octets), bucket non configure ou local.", pdfBytes.length);
            return "local-generated: " + key;
        } catch (Exception e) {
            log.error("Erreur lors de la generation ou upload du recu PDF: {}", e.getMessage());
            return "error: " + e.getMessage();
        }
    }
}
