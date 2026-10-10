document.addEventListener('DOMContentLoaded', () => {
    initTabs();
    initEventHandlers();
    refreshClusterStatus();
    loadStats();
    loadBooks();
    loadMembers();
    loadLoans();
    loadOverdueLoans();
    populateSelects();

    // Actualisation reguliere du statut ALB (pour visualiser la repartition multi-AZ en direct)
    setInterval(refreshClusterStatus, 4000);
});

// --- Onglets ---
function initTabs() {
    const tabButtons = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');

    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const targetId = btn.getAttribute('data-tab');

            tabButtons.forEach(b => b.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));

            btn.classList.add('active');
            const targetContent = document.getElementById(targetId);
            if (targetContent) targetContent.classList.add('active');

            if (targetId === 'tab-books') loadBooks();
            if (targetId === 'tab-members') loadMembers();
            if (targetId === 'tab-loans') loadLoans();
            if (targetId === 'tab-overdue') loadOverdueLoans();
            if (targetId === 'tab-new-loan') populateSelects();
            if (targetId === 'tab-health') refreshHealthTab();
        });
    });
}

// --- Actualisation Statut ALB & Multi-AZ ---
async function refreshClusterStatus() {
    try {
        const res = await fetch('/api/info');
        if (!res.ok) throw new Error('ALB indisponible');
        const data = await res.json();

        document.getElementById('statusLabel').textContent = 'ALB: En ligne & équilibré';
        document.getElementById('badgeAz').textContent = `AZ: ${data.availabilityZone || 'N/A'}`;
        document.getElementById('badgeInstance').textContent = `Instance: ${data.instanceId || 'N/A'}`;
        document.getElementById('badgeDb').textContent = 'PostgreSQL: Connecté';
        document.getElementById('badgeDb').style.color = '#34d399';

        // Mettre a jour l'affichage JSON si on est sur l'onglet sante
        const instEl = document.getElementById('instanceDetailsJson');
        if (instEl) instEl.textContent = JSON.stringify(data, null, 2);
    } catch (e) {
        document.getElementById('statusLabel').textContent = 'ALB: Hors ligne ou en panne';
        document.getElementById('badgeDb').textContent = 'Erreur';
        document.getElementById('badgeDb').style.color = '#f87171';
    }
}

async function refreshHealthTab() {
    refreshClusterStatus();
    try {
        const res = await fetch('/health');
        const data = await res.json();
        document.getElementById('healthDetailsJson').textContent = JSON.stringify(data, null, 2);
    } catch (e) {
        document.getElementById('healthDetailsJson').textContent = JSON.stringify({ error: e.message, status: "DOWN" }, null, 2);
    }
}

// --- Statistiques ---
async function loadStats() {
    try {
        const res = await fetch('/api/stats');
        const data = await res.json();
        document.getElementById('statBooks').textContent = data.totalBooks ?? 0;
        document.getElementById('statMembers').textContent = data.totalMembers ?? 0;
        document.getElementById('statLoans').textContent = data.activeLoans ?? 0;
        document.getElementById('statOverdue').textContent = data.overdueLoans ?? 0;
    } catch (e) {
        console.warn('Erreur chargement stats:', e);
    }
}

// --- Livres ---
async function loadBooks(query = '') {
    const tbody = document.getElementById('booksTableBody');
    tbody.innerHTML = '<tr><td colspan="5" class="loading-cell">Chargement des livres...</td></tr>';
    try {
        const url = query ? `/api/books?q=${encodeURIComponent(query)}` : '/api/books';
        const res = await fetch(url);
        const books = await res.json();

        if (books.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="loading-cell">Aucun livre trouvé.</td></tr>';
            return;
        }

        tbody.innerHTML = books.map(b => `
            <tr>
                <td><strong>#${b.id}</strong></td>
                <td><strong>${escapeHtml(b.title)}</strong></td>
                <td>${escapeHtml(b.author)}</td>
                <td><span class="meta-badge">${escapeHtml(b.category)}</span></td>
                <td><code>${escapeHtml(b.isbn)}</code></td>
            </tr>
        `).join('');
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="5" class="loading-cell" style="color:#ef4444;">Erreur: ${e.message}</td></tr>`;
    }
}

// --- Adhérents ---
async function loadMembers() {
    const tbody = document.getElementById('membersTableBody');
    tbody.innerHTML = '<tr><td colspan="3" class="loading-cell">Chargement des adhérents...</td></tr>';
    try {
        const res = await fetch('/api/members');
        const members = await res.json();

        if (members.length === 0) {
            tbody.innerHTML = '<tr><td colspan="3" class="loading-cell">Aucun adhérent enregistré.</td></tr>';
            return;
        }

        tbody.innerHTML = members.map(m => `
            <tr>
                <td><strong>#${m.id}</strong></td>
                <td>${escapeHtml(m.name)}</td>
                <td><a href="mailto:${escapeHtml(m.email)}" style="color:#818cf8;">${escapeHtml(m.email)}</a></td>
            </tr>
        `).join('');
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="3" class="loading-cell" style="color:#ef4444;">Erreur: ${e.message}</td></tr>`;
    }
}

// --- Prêts ---
async function loadLoans() {
    const tbody = document.getElementById('loansTableBody');
    tbody.innerHTML = '<tr><td colspan="7" class="loading-cell">Chargement des prêts...</td></tr>';
    try {
        const res = await fetch('/api/loans');
        const loans = await res.json();

        if (loans.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" class="loading-cell">Aucun prêt en cours.</td></tr>';
            return;
        }

        tbody.innerHTML = loans.map(l => `
            <tr>
                <td>#${l.id}</td>
                <td><strong>${escapeHtml(l.bookTitle)}</strong></td>
                <td>${escapeHtml(l.memberName)}</td>
                <td>${l.borrowDate}</td>
                <td>${l.dueDate}</td>
                <td>
                    <span class="${l.overdue ? 'badge-overdue' : 'badge-active'}">
                        ${l.overdue ? 'EN RETARD' : 'En cours'}
                    </span>
                </td>
                <td>
                    <button class="btn btn-secondary btn-sm" onclick="returnBook(${l.id})">📥 Rendre</button>
                </td>
            </tr>
        `).join('');
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="7" class="loading-cell" style="color:#ef4444;">Erreur: ${e.message}</td></tr>`;
    }
}

// --- Prêts en retard ---
async function loadOverdueLoans() {
    const tbody = document.getElementById('overdueTableBody');
    tbody.innerHTML = '<tr><td colspan="5" class="loading-cell">Chargement des retards...</td></tr>';
    try {
        const res = await fetch('/api/loans/overdue');
        const overdue = await res.json();

        if (overdue.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="loading-cell">Aucun retard pour le moment ! Tout est à jour.</td></tr>';
            return;
        }

        tbody.innerHTML = overdue.map(l => `
            <tr>
                <td>#${l.id}</td>
                <td><strong>${escapeHtml(l.bookTitle)}</strong></td>
                <td>${escapeHtml(l.memberName)}</td>
                <td><strong style="color:#f87171;">${l.dueDate}</strong></td>
                <td>
                    <button class="btn btn-danger btn-sm" onclick="returnBook(${l.id})">📥 Clôturer & Régulariser</button>
                </td>
            </tr>
        `).join('');
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="5" class="loading-cell" style="color:#ef4444;">Erreur: ${e.message}</td></tr>`;
    }
}

// --- Action Retour de Livre ---
window.returnBook = async function(loanId) {
    if (!confirm(`Confirmer le retour de l'ouvrage pour le prêt #${loanId} ?`)) return;
    try {
        const res = await fetch(`/api/loans/${loanId}/return`, { method: 'POST' });
        if (!res.ok) {
            const err = await res.text();
            alert(`Erreur: ${err}`);
            return;
        }
        const data = await res.json();
        alert(`Ouvrage retourné avec succès !\nReçu d'archivage S3 : ${data.receiptUrl}`);
        loadLoans();
        loadOverdueLoans();
        loadStats();
    } catch (e) {
        alert(`Erreur: ${e.message}`);
    }
};

// --- Remplir Sélecteurs de formulaires ---
async function populateSelects() {
    try {
        const [booksRes, membersRes] = await Promise.all([fetch('/api/books'), fetch('/api/members')]);
        const books = await booksRes.json();
        const members = await membersRes.json();

        const bSelect = document.getElementById('loanBookSelect');
        bSelect.innerHTML = '<option value="">-- Choisir un livre disponible --</option>' +
            books.map(b => `<option value="${b.id}">${escapeHtml(b.title)} (${escapeHtml(b.author)})</option>`).join('');

        const mSelect = document.getElementById('loanMemberSelect');
        mSelect.innerHTML = '<option value="">-- Choisir un adhérent --</option>' +
            members.map(m => `<option value="${m.id}">${escapeHtml(m.name)}</option>`).join('');
    } catch (e) {
        console.warn('Erreur remplissage selects:', e);
    }
}

// --- Gestionnaires d'Événements ---
function initEventHandlers() {
    // Recherche livre
    document.getElementById('bookSearchBtn').addEventListener('click', () => {
        const q = document.getElementById('bookSearchInput').value;
        loadBooks(q);
    });
    document.getElementById('bookSearchInput').addEventListener('keyup', (e) => {
        if (e.key === 'Enter') {
            loadBooks(e.target.value);
        }
    });

    // Formulaire Ajout Livre
    document.getElementById('addBookForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const book = {
            title: document.getElementById('bookTitle').value,
            author: document.getElementById('bookAuthor').value,
            category: document.getElementById('bookCategory').value,
            isbn: document.getElementById('bookIsbn').value
        };

        try {
            const res = await fetch('/api/books', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(book)
            });
            if (res.ok) {
                alert('Livre ajouté avec succès au catalogue !');
                document.getElementById('addBookForm').reset();
                loadBooks();
                loadStats();
            } else {
                alert('Erreur lors de l\'ajout: ' + await res.text());
            }
        } catch (err) {
            alert('Erreur: ' + err.message);
        }
    });

    // Formulaire Inscription Adhérent
    document.getElementById('addMemberForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const member = {
            name: document.getElementById('memberName').value,
            email: document.getElementById('memberEmail').value
        };

        try {
            const res = await fetch('/api/members', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(member)
            });
            if (res.ok) {
                alert('Adhérent inscrit avec succès !');
                document.getElementById('addMemberForm').reset();
                loadMembers();
                loadStats();
            } else {
                alert('Erreur lors de l\'inscription: ' + await res.text());
            }
        } catch (err) {
            alert('Erreur: ' + err.message);
        }
    });

    // Formulaire Nouveau Prêt
    document.getElementById('newLoanForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const body = {
            bookId: document.getElementById('loanBookSelect').value,
            memberId: document.getElementById('loanMemberSelect').value,
            days: document.getElementById('loanDays').value
        };

        try {
            const res = await fetch('/api/loans', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            });

            const box = document.getElementById('receiptResult');
            if (res.ok) {
                const data = await res.json();
                box.classList.remove('hidden');
                box.innerHTML = `
                    <strong>✅ Prêt #${data.loanId} enregistré avec succès !</strong><br>
                    Adhérent : ${escapeHtml(data.memberName)}<br>
                    Ouvrage : ${escapeHtml(data.bookTitle)}<br>
                    Échéance : ${data.dueDate}<br>
                    <strong>Reçu S3 :</strong> <code>${escapeHtml(data.receiptUrl)}</code>
                `;
                document.getElementById('newLoanForm').reset();
                loadStats();
            } else {
                box.classList.remove('hidden');
                box.innerHTML = `<span style="color:#ef4444;">⚠️ Échec du prêt : ${await res.text()}</span>`;
            }
        } catch (err) {
            alert('Erreur: ' + err.message);
        }
    });

    document.getElementById('refreshLoansBtn').addEventListener('click', loadLoans);
    document.getElementById('refreshHealthBtn').addEventListener('click', refreshHealthTab);
}

function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, "&amp;")
              .replace(/</g, "&lt;")
              .replace(/>/g, "&gt;")
              .replace(/"/g, "&quot;")
              .replace(/'/g, "&#039;");
}
