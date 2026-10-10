package com.library.service;

import com.library.db.DBConnection;
import com.library.model.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class LibraryService {
    private static final Logger log = LoggerFactory.getLogger(LibraryService.class);

    public List<Book> getBooks(String query) {
        List<Book> list = new ArrayList<>();
        String sql = "SELECT id, title, isbn, author, category FROM books";
        boolean hasQuery = query != null && !query.trim().isEmpty();
        if (hasQuery) {
            sql += " WHERE LOWER(title) LIKE ? OR LOWER(author) LIKE ? OR LOWER(category) LIKE ?";
        }
        sql += " ORDER BY id DESC";

        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            if (hasQuery) {
                String pattern = "%" + query.trim().toLowerCase() + "%";
                ps.setString(1, pattern);
                ps.setString(2, pattern);
                ps.setString(3, pattern);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(new Book(
                            rs.getInt("id"),
                            rs.getString("title"),
                            rs.getString("isbn"),
                            rs.getString("author"),
                            rs.getString("category")
                    ));
                }
            }
        } catch (Exception e) {
            log.error("Erreur recuperation livres: {}", e.getMessage());
        }
        return list;
    }

    public Book addBook(Book book) throws Exception {
        String sql = "INSERT INTO books(title, isbn, author, category) VALUES (?, ?, ?, ?) RETURNING id";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, book.getTitle());
            ps.setString(2, book.getIsbn());
            ps.setString(3, book.getAuthor());
            ps.setString(4, book.getCategory());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    book.setId(rs.getInt(1));
                    // Creer un exemplaire disponible par defaut
                    addCopy(conn, book.getId());
                    return book;
                }
            }
        }
        throw new SQLException("Echec de creation du livre");
    }

    private void addCopy(Connection conn, int bookId) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement("INSERT INTO copies(book_id, status) VALUES (?, 'AVAILABLE')")) {
            ps.setInt(1, bookId);
            ps.executeUpdate();
        }
    }

    public List<Member> getMembers() {
        List<Member> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT id, name, email FROM members ORDER BY id DESC")) {
            while (rs.next()) {
                list.add(new Member(rs.getInt("id"), rs.getString("name"), rs.getString("email")));
            }
        } catch (Exception e) {
            log.error("Erreur recuperation adherents: {}", e.getMessage());
        }
        return list;
    }

    public Member addMember(Member member) throws Exception {
        String sql = "INSERT INTO members(name, email) VALUES (?, ?) RETURNING id";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, member.getName());
            ps.setString(2, member.getEmail());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    member.setId(rs.getInt(1));
                    return member;
                }
            }
        }
        throw new SQLException("Echec de creation de l'adherent");
    }

    public List<LoanView> getLoans(boolean overdueOnly) {
        List<LoanView> list = new ArrayList<>();
        String sql = "SELECT l.id, l.copy_id, c.book_id, b.title as book_title, " +
                "l.member_id, m.name as member_name, l.borrow_date, l.due_date, l.return_date " +
                "FROM loans l " +
                "JOIN copies c ON l.copy_id = c.id " +
                "JOIN books b ON c.book_id = b.id " +
                "JOIN members m ON l.member_id = m.id " +
                "WHERE l.return_date IS NULL ";

        if (overdueOnly) {
            sql += "AND l.due_date < CURRENT_DATE ";
        }
        sql += "ORDER BY l.due_date ASC";

        try (Connection conn = DBConnection.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            LocalDate today = LocalDate.now();
            while (rs.next()) {
                LocalDate dueDate = rs.getDate("due_date").toLocalDate();
                boolean isOverdue = dueDate.isBefore(today);
                Date retDate = rs.getDate("return_date");
                list.add(new LoanView(
                        rs.getInt("id"),
                        rs.getInt("copy_id"),
                        rs.getInt("book_id"),
                        rs.getString("book_title"),
                        rs.getInt("member_id"),
                        rs.getString("member_name"),
                        rs.getDate("borrow_date").toLocalDate(),
                        dueDate,
                        retDate != null ? retDate.toLocalDate() : null,
                        isOverdue
                ));
            }
        } catch (Exception e) {
            log.error("Erreur recuperation prets: {}", e.getMessage());
        }
        return list;
    }

    public Map<String, Object> createLoan(int bookId, int memberId, int durationDays) throws Exception {
        try (Connection conn = DBConnection.getConnection()) {
            conn.setAutoCommit(false);
            try {
                // Trouver une copie disponible
                int copyId = -1;
                try (PreparedStatement ps = conn.prepareStatement("SELECT id FROM copies WHERE book_id = ? AND status = 'AVAILABLE' LIMIT 1 FOR UPDATE")) {
                    ps.setInt(1, bookId);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            copyId = rs.getInt(1);
                        }
                    }
                }

                if (copyId == -1) {
                    throw new IllegalStateException("Aucun exemplaire disponible pour ce livre.");
                }

                // Inserer le pret
                LocalDate borrowDate = LocalDate.now();
                LocalDate dueDate = borrowDate.plusDays(durationDays > 0 ? durationDays : 14);
                int loanId;
                try (PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO loans(copy_id, member_id, borrow_date, due_date) VALUES (?, ?, ?, ?) RETURNING id")) {
                    ps.setInt(1, copyId);
                    ps.setInt(2, memberId);
                    ps.setDate(3, Date.valueOf(borrowDate));
                    ps.setDate(4, Date.valueOf(dueDate));
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        loanId = rs.getInt(1);
                    }
                }

                // Mettre a jour le statut de la copie
                try (PreparedStatement ps = conn.prepareStatement("UPDATE copies SET status = 'BORROWED' WHERE id = ?")) {
                    ps.setInt(1, copyId);
                    ps.executeUpdate();
                }

                // Recuperer le nom du membre et titre du livre pour le recu
                String memberName = "Adherent";
                String bookTitle = "Livre";
                try (PreparedStatement ps = conn.prepareStatement("SELECT name FROM members WHERE id = ?")) {
                    ps.setInt(1, memberId);
                    try (ResultSet rs = ps.executeQuery()) { if (rs.next()) memberName = rs.getString(1); }
                }
                try (PreparedStatement ps = conn.prepareStatement("SELECT title FROM books WHERE id = ?")) {
                    ps.setInt(1, bookId);
                    try (ResultSet rs = ps.executeQuery()) { if (rs.next()) bookTitle = rs.getString(1); }
                }

                conn.commit();

                // Generer le recu PDF et l'archiver dans S3
                String s3ReceiptUrl = S3ReceiptService.generateAndUploadReceipt(loanId, memberName, bookTitle, "EMPRUNT");

                Map<String, Object> result = new HashMap<>();
                result.put("loanId", loanId);
                result.put("copyId", copyId);
                result.put("memberName", memberName);
                result.put("bookTitle", bookTitle);
                result.put("borrowDate", borrowDate.toString());
                result.put("dueDate", dueDate.toString());
                result.put("receiptUrl", s3ReceiptUrl);
                return result;
            } catch (Exception e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    public Map<String, Object> returnLoan(int loanId) throws Exception {
        try (Connection conn = DBConnection.getConnection()) {
            conn.setAutoCommit(false);
            try {
                int copyId = -1;
                int memberId = -1;
                try (PreparedStatement ps = conn.prepareStatement("SELECT copy_id, member_id FROM loans WHERE id = ? AND return_date IS NULL FOR UPDATE")) {
                    ps.setInt(1, loanId);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            copyId = rs.getInt("copy_id");
                            memberId = rs.getInt("member_id");
                        }
                    }
                }

                if (copyId == -1) {
                    throw new IllegalStateException("Pret introuvable ou deja retourne.");
                }

                // Marquer comme retourne
                LocalDate returnDate = LocalDate.now();
                try (PreparedStatement ps = conn.prepareStatement("UPDATE loans SET return_date = ? WHERE id = ?")) {
                    ps.setDate(1, Date.valueOf(returnDate));
                    ps.setInt(2, loanId);
                    ps.executeUpdate();
                }

                // Remettre la copie disponible
                try (PreparedStatement ps = conn.prepareStatement("UPDATE copies SET status = 'AVAILABLE' WHERE id = ?")) {
                    ps.setInt(1, copyId);
                    ps.executeUpdate();
                }

                // Infos pour recu de retour
                String memberName = "Adherent";
                String bookTitle = "Livre";
                try (PreparedStatement ps = conn.prepareStatement("SELECT name FROM members WHERE id = ?")) {
                    ps.setInt(1, memberId);
                    try (ResultSet rs = ps.executeQuery()) { if (rs.next()) memberName = rs.getString(1); }
                }
                try (PreparedStatement ps = conn.prepareStatement("SELECT b.title FROM books b JOIN copies c ON b.id = c.book_id WHERE c.id = ?")) {
                    ps.setInt(1, copyId);
                    try (ResultSet rs = ps.executeQuery()) { if (rs.next()) bookTitle = rs.getString(1); }
                }

                conn.commit();

                String s3ReceiptUrl = S3ReceiptService.generateAndUploadReceipt(loanId, memberName, bookTitle, "RETOUR");

                Map<String, Object> result = new HashMap<>();
                result.put("loanId", loanId);
                result.put("returnDate", returnDate.toString());
                result.put("status", "RETURNED");
                result.put("receiptUrl", s3ReceiptUrl);
                return result;
            } catch (Exception e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    public Map<String, Object> getStats() {
        Map<String, Object> stats = new HashMap<>();
        try (Connection conn = DBConnection.getConnection();
             Statement stmt = conn.createStatement()) {
            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM books")) {
                if (rs.next()) stats.put("totalBooks", rs.getInt(1));
            }
            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM members")) {
                if (rs.next()) stats.put("totalMembers", rs.getInt(1));
            }
            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM loans WHERE return_date IS NULL")) {
                if (rs.next()) stats.put("activeLoans", rs.getInt(1));
            }
            try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM loans WHERE return_date IS NULL AND due_date < CURRENT_DATE")) {
                if (rs.next()) stats.put("overdueLoans", rs.getInt(1));
            }
        } catch (Exception e) {
            log.error("Erreur recuperation stats: {}", e.getMessage());
            stats.put("totalBooks", 0);
            stats.put("totalMembers", 0);
            stats.put("activeLoans", 0);
            stats.put("overdueLoans", 0);
        }
        return stats;
    }
}
