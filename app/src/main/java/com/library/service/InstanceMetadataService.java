package com.library.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

public class InstanceMetadataService {
    private static final Logger log = LoggerFactory.getLogger(InstanceMetadataService.class);
    private static final String IMDS_TOKEN_URL = "http://169.254.169.254/latest/api/token";
    private static final String IMDS_METADATA_URL = "http://169.254.169.254/latest/meta-data/";

    private static String cachedInstanceId;
    private static String cachedAz;
    private static String cachedPrivateIp;
    private static boolean initialized = false;

    public static synchronized Map<String, String> getMetadata() {
        if (!initialized) {
            fetchMetadata();
            initialized = true;
        }

        Map<String, String> meta = new HashMap<>();
        meta.put("instanceId", cachedInstanceId != null ? cachedInstanceId : "local-standalone");
        meta.put("availabilityZone", cachedAz != null ? cachedAz : "us-east-1-local");
        meta.put("privateIp", cachedPrivateIp != null ? cachedPrivateIp : "127.0.0.1");
        return meta;
    }

    private static void fetchMetadata() {
        try {
            // IMDSv2 : Recuperation du jeton de session
            URL tokenUrl = new URL(IMDS_TOKEN_URL);
            HttpURLConnection tokenConn = (HttpURLConnection) tokenUrl.openConnection();
            tokenConn.setRequestMethod("PUT");
            tokenConn.setRequestProperty("X-aws-ec2-metadata-token-ttl-seconds", "60");
            tokenConn.setConnectTimeout(800);
            tokenConn.setReadTimeout(800);

            if (tokenConn.getResponseCode() == 200) {
                String token;
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(tokenConn.getInputStream()))) {
                    token = reader.readLine();
                }

                cachedInstanceId = queryImds("instance-id", token);
                cachedAz = queryImds("placement/availability-zone", token);
                cachedPrivateIp = queryImds("local-ipv4", token);
                log.info("Metadonnees AWS recuperees: InstanceId={}, AZ={}, IP={}", cachedInstanceId, cachedAz, cachedPrivateIp);
                return;
            }
        } catch (Exception e) {
            log.debug("IMDSv2 indisponible (environnement local ou non-EC2): {}", e.getMessage());
        }

        // Fallback local
        try {
            cachedInstanceId = System.getenv().getOrDefault("HOSTNAME", InetAddress.getLocalHost().getHostName());
            cachedPrivateIp = InetAddress.getLocalHost().getHostAddress();
            cachedAz = System.getenv().getOrDefault("AWS_AZ", "local-dev");
        } catch (Exception e) {
            cachedInstanceId = "local-instance";
            cachedPrivateIp = "127.0.0.1";
            cachedAz = "local-zone";
        }
    }

    private static String queryImds(String path, String token) {
        try {
            URL url = new URL(IMDS_METADATA_URL + path);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("X-aws-ec2-metadata-token", token);
            conn.setConnectTimeout(800);
            conn.setReadTimeout(800);
            if (conn.getResponseCode() == 200) {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()))) {
                    return reader.readLine();
                }
            }
        } catch (Exception ignored) {}
        return "unknown";
    }
}
