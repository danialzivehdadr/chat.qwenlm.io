import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

/**
 * Secure Repository Owner Access Control
 * Only the owner can access the direct link within the defined framework.
 *
 * @author Danial Zivehdar
 * @version 1.0
 */
public class RepoOwnerAccess {

    // ─────────────────────────────────────────────
    // Owner Identity
    // ─────────────────────────────────────────────

    static class OwnerIdentity {
        private final String ownerId;
        private final String ownerName;
        private final String ownerEmail;
        private final String accessKey;
        private final LocalDateTime createdAt;
        private boolean isActive;

        public OwnerIdentity(String ownerName, String ownerEmail) {
            this.ownerId = generateOwnerId();
            this.ownerName = ownerName;
            this.ownerEmail = ownerEmail;
            this.accessKey = generateAccessKey();
            this.createdAt = LocalDateTime.now();
            this.isActive = true;
        }

        private String generateOwnerId() {
            SecureRandom random = new SecureRandom();
            byte[] bytes = new byte[16];
            random.nextBytes(bytes);
            return "OWN-" + Base64.getUrlEncoder().withoutPadding()
                    .encodeToString(bytes).substring(0, 12).toUpperCase();
        }

        private String generateAccessKey() {
            SecureRandom random = new SecureRandom();
            byte[] bytes = new byte[32];
            random.nextBytes(bytes);
            return Base64.getUrlEncoder().withoutPadding()
                    .encodeToString(bytes).substring(0, 24);
        }

        public String getOwnerId() { return ownerId; }
        public String getOwnerName() { return ownerName; }
        public String getOwnerEmail() { return ownerEmail; }
        public String getAccessKey() { return accessKey; }
        public LocalDateTime getCreatedAt() { return createdAt; }
        public boolean isActive() { return isActive; }
        public void deactivate() { this.isActive = false; }

        @Override
        public String toString() {
            return String.format("Owner ID: %s | Name: %s | Email: %s | Active: %s",
                    ownerId, ownerName, ownerEmail, isActive ? "YES" : "NO");
        }
    }

    // ─────────────────────────────────────────────
    // Direct Link Generator (Owner Only)
    // ─────────────────────────────────────────────

    static class DirectLink {
        private final String url;
        private final String ownerId;
        private final String token;
        private final LocalDateTime expiresAt;

        public DirectLink(String baseUrl, OwnerIdentity owner) {
            this.ownerId = owner.getOwnerId();
            this.token = generateToken(owner);
            this.url = baseUrl + "?owner_id=" + ownerId + "&token=" + token;
            this.expiresAt = LocalDateTime.now().plusHours(24);
        }

        private String generateToken(OwnerIdentity owner) {
            try {
                String data = owner.getOwnerId() + ":" + owner.getAccessKey()
                        + ":" + System.currentTimeMillis();
                MessageDigest digest = MessageDigest.getInstance("SHA-256");
                byte[] hash = digest.digest(data.getBytes());
                return Base64.getUrlEncoder().withoutPadding()
                        .encodeToString(hash).substring(0, 20);
            } catch (Exception e) {
                throw new RuntimeException("Token generation failed", e);
            }
        }

        public String getUrl() { return url; }
        public String getOwnerId() { return ownerId; }
        public String getToken() { return token; }
        public LocalDateTime getExpiresAt() { return expiresAt; }

        public boolean isExpired() {
            return LocalDateTime.now().isAfter(expiresAt);
        }

        @Override
        public String toString() {
            return String.format("URL: %s\nExpires: %s",
                    url, expiresAt.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")));
        }
    }

    // ─────────────────────────────────────────────
    // Access Control Framework
    // ─────────────────────────────────────────────

    static class AccessFramework {
        private final Map<String, OwnerIdentity> registeredOwners;
        private final Map<String, DirectLink> activeLinks;

        public AccessFramework() {
            this.registeredOwners = new HashMap<>();
            this.activeLinks = new HashMap<>();
        }

        /**
         * Register a new owner (only within framework).
         */
        public OwnerIdentity registerOwner(String name, String email) {
            OwnerIdentity owner = new OwnerIdentity(name, email);
            registeredOwners.put(owner.getOwnerId(), owner);
            System.out.println("[REGISTERED] " + owner);
            return owner;
        }

        /**
         * Generate direct link - OWNER ONLY.
         */
        public DirectLink generateDirectLink(String ownerId, String baseUrl) {
            OwnerIdentity owner = registeredOwners.get(ownerId);

            if (owner == null) {
                System.out.println("[DENIED] Owner ID not found: " + ownerId);
                return null;
            }

            if (!owner.isActive()) {
                System.out.println("[DENIED] Owner account is deactivated.");
                return null;
            }

            DirectLink link = new DirectLink(baseUrl, owner);
            activeLinks.put(link.getToken(), link);
            System.out.println("[GRANTED] Direct link generated for owner: " + owner.getOwnerName());
            return link;
        }

        /**
         * Validate access - only owner with valid token can connect.
         */
        public boolean validateAccess(String ownerId, String token) {
            DirectLink link = activeLinks.get(token);

            if (link == null) {
                System.out.println("[ACCESS DENIED] Invalid token.");
                return false;
            }

            if (!link.getOwnerId().equals(ownerId)) {
                System.out.println("[ACCESS DENIED] Owner ID mismatch.");
                return false;
            }

            if (link.isExpired()) {
                System.out.println("[ACCESS DENIED] Link expired.");
                return false;
            }

            System.out.println("[ACCESS GRANTED] Owner verified successfully.");
            return true;
        }

        /**
         * Revoke access immediately.
         */
        public void revokeAccess(String token) {
            activeLinks.remove(token);
            System.out.println("[REVOKED] Access link removed.");
        }
    }

    // ─────────────────────────────────────────────
    // Main - Example Usage
    // ─────────────────────────────────────────────

    public static void main(String[] args) {

        AccessFramework framework = new AccessFramework();

        System.out.println("══════════════════════════════════════════════════");
        System.out.println("   REPO OWNER ACCESS CONTROL - FRAMEWORK");
        System.out.println("══════════════════════════════════════════════════\n");

        // 1. Register owner
        OwnerIdentity owner = framework.registerOwner(
                "Danial Zivehdar",
                "danialzivehdar1992@gmail.com"
        );

        System.out.println("\n──────────────────────────────────────────────────");
        System.out.println("  OWNER CREDENTIALS (CONFIDENTIAL)");
        System.out.println("──────────────────────────────────────────────────");
        System.out.println("  Owner ID   : " + owner.getOwnerId());
        System.out.println("  Access Key : " + owner.getAccessKey());
        System.out.println("  Created At : " + owner.getCreatedAt());
        System.out.println("──────────────────────────────────────────────────\n");

        // 2. Generate direct link (owner only)
        DirectLink link = framework.generateDirectLink(
                owner.getOwnerId(),
                "https://your-repo.com/direct-access"
        );

        if (link != null) {
            System.out.println("\n  DIRECT LINK (Owner Only):");
            System.out.println("  " + link.getUrl());
            System.out.println("  Expires: " + link.getExpiresAt() + "\n");
        }

        // 3. Validate access
        System.out.println("──────────────────────────────────────────────────");
        System.out.println("  ACCESS VALIDATION TEST");
        System.out.println("──────────────────────────────────────────────────");

        // Valid owner
        framework.validateAccess(owner.getOwnerId(), link.getToken());

        // Invalid owner (someone else tries)
        System.out.println();
        framework.validateAccess("OWN-FAKE123456", link.getToken());

        System.out.println("\n══════════════════════════════════════════════════");
    }
}
