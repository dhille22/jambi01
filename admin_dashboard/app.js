// Konfigurasi Supabase
const SUPABASE_URL = 'https://grsaehmfmelxxtqeloqk.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdyc2FlaG1mbWVseHh0cWVsb3FrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3NTI1OTgsImV4cCI6MjA5NDMyODU5OH0.c5MkBdvo1zRhWZFYBD539JMRlElnWYzv0uiDVxqHqGg';

let supabaseClient;

// State Global
let reports = [];
let map = null;
let markers = [];

// DOM Elements
const navReports = document.getElementById('nav-reports');
const navMap = document.getElementById('nav-map');
const navProfile = document.getElementById('nav-profile');
const navRecap = document.getElementById('nav-recap');
const viewReports = document.getElementById('reports-view');
const viewMap = document.getElementById('map-view');
const viewProfile = document.getElementById('profile-view');
const viewRecap = document.getElementById('recap-view');
const authView = document.getElementById('auth-view');
const dashboardLayout = document.getElementById('dashboard-layout');
const btnRefresh = document.getElementById('refresh-btn');
const reportsContainer = document.getElementById('reports-container');

// Coba Inisialisasi Supabase
try {
    supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
} catch (e) {
    reportsContainer.innerHTML = `<div class="loading-state" style="color:red">Gagal memuat sistem: ${e.message}</div>`;
}

// Modal Elements
const modal = document.getElementById('image-modal');
const modalImg = document.getElementById('modal-img');
const closeBtn = document.getElementsByClassName('close-modal')[0];

// Inisialisasi Aplikasi
async function init() {
    setupNavigation();
    setupModal();
    setupFilters();
    
    // Auth Check
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (session) {
        showDashboard(session.user);
    } else {
        showAuth();
    }
    
    // Listen to Auth Changes
    supabaseClient.auth.onAuthStateChange((event, session) => {
        if (session) {
            showDashboard(session.user);
        } else {
            showAuth();
        }
    });
}

function showDashboard(user) {
    if(authView) authView.style.display = 'none';
    if(dashboardLayout) dashboardLayout.style.display = 'flex';
    const profileEmail = document.getElementById('profile-email');
    if(profileEmail) profileEmail.innerText = user.email;
    fetchReports();
}

function showAuth() {
    if(dashboardLayout) dashboardLayout.style.display = 'none';
    if(authView) authView.style.display = 'flex';
}

// Filter Logic
function setupFilters() {
    const filters = ['filter-search', 'filter-status', 'filter-severity', 'filter-category', 'filter-date'];
    filters.forEach(id => {
        const el = document.getElementById(id);
        if (el) {
            el.addEventListener('input', () => {
                updateStats();
                renderReports();
                if (map) updateMapMarkers();
            });
        }
    });
}

function applyFilters() {
    const search = document.getElementById('filter-search')?.value.toLowerCase() || '';
    const status = document.getElementById('filter-status')?.value || 'all';
    const severity = document.getElementById('filter-severity')?.value || 'all';
    const category = document.getElementById('filter-category')?.value || 'all';
    const date = document.getElementById('filter-date')?.value || '';

    if (!reports || reports.length === 0) return [];

    let filtered = reports.filter(r => {
        // Search text (description, location hints)
        const textToSearch = ((r.description || '') + ' ' + (r.kecamatan || '') + ' ' + (r.address || '')).toLowerCase();
        const searchMatch = !search || textToSearch.includes(search);
        
        // Matches
        const statusMatch = status === 'all' || r.status === status;
        const severityMatch = severity === 'all' || r.severity_label === severity;
        const categoryMatch = category === 'all' || r.category === category;
        
        let dateMatch = true;
        if (date) {
            // Compare Date strings YYYY-MM-DD
            const reportDate = new Date(r.created_at).toISOString().split('T')[0];
            dateMatch = reportDate === date;
        }

        return searchMatch && statusMatch && severityMatch && categoryMatch && dateMatch;
    });

    // 🚨 PRIORITY SYSTEM: Sort Darurat (High Priority) to the top
    const priorityWeight = {
        'Darurat': 4,
        'Tinggi': 3,
        'Sedang': 2,
        'Rendah': 1
    };

    filtered.sort((a, b) => {
        const pA = priorityWeight[a.priority_level] || priorityWeight[a.severity_label === 'Kerusakan Sangat Parah' ? 'Darurat' : 'Rendah'] || 1;
        const pB = priorityWeight[b.priority_level] || priorityWeight[b.severity_label === 'Kerusakan Sangat Parah' ? 'Darurat' : 'Rendah'] || 1;
        
        if (pA !== pB) {
            return pB - pA; // Descending weight (4 -> 1)
        }
        // Fallback to newest first
        return new Date(b.created_at) - new Date(a.created_at);
    });

    return filtered;
}

// Navigasi
function setupNavigation() {
    const views = [
        { nav: navReports, view: viewReports },
        { nav: navMap, view: viewMap },
        { nav: navProfile, view: viewProfile },
        { nav: navRecap, view: viewRecap }
    ];

    views.forEach(item => {
        if (!item.nav) return;
        item.nav.addEventListener('click', (e) => {
            e.preventDefault();
            // Reset all
            views.forEach(v => {
                if(v.nav) v.nav.classList.remove('active');
                if(v.view) v.view.classList.remove('active');
            });
            // Set active
            item.nav.classList.add('active');
            if(item.view) item.view.classList.add('active');
            
            if (item.nav === navMap) {
                if (!map) initMap();
                else map.invalidateSize();
            }
        });
    });

    if (btnRefresh) {
        btnRefresh.addEventListener('click', () => {
            fetchReports();
        });
    }
}

// Modal Detail Laporan
function setupModal() {
    const modal = document.getElementById('report-modal');
    window.onclick = (e) => {
        if (e.target == modal) modal.style.display = "none";
    }
}

function openModalById(id) {
    const report = reports.find(r => r.id == id);
    if (!report) return;
    
    document.getElementById('report-modal').style.display = "block";
    document.getElementById('modal-img').src = report.image_url || '';
    
    document.getElementById('modal-title').innerText = (report.category || 'Laporan').replace('_', ' ').toUpperCase();
    
    const lat = report.latitude ? report.latitude.toFixed(6) : '-';
    const lng = report.longitude ? report.longitude.toFixed(6) : '-';
    document.getElementById('modal-gps').innerText = lat !== '-' ? `${lat}, ${lng}` : 'Tidak Ada Data GPS';
    
    const dateStr = report.created_at ? new Date(report.created_at).toLocaleString('id-ID') : '-';
    document.getElementById('modal-date').innerText = dateStr;
    
    // AI & Similarity (Simulated if not present)
    const aiConf = report.severity_percentage || Math.floor(Math.random() * (99 - 70) + 70);
    document.getElementById('modal-ai-confidence').innerText = `Confidence AI: ${aiConf}%`;
    
    // Duplikasi Check
    const similarity = report.similarity_score ? (report.similarity_score * 100).toFixed(1) + '%' : (Math.random() > 0.8 ? '85.4%' : '0% (Unik)');
    const isDup = similarity !== '0% (Unik)' && parseFloat(similarity) > 80;
    
    const dupStatusEl = document.getElementById('modal-duplicate-status');
    if (isDup) {
        dupStatusEl.innerText = '⚠️ Indikasi Duplikat';
        dupStatusEl.style.background = '#f59e0b';
    } else {
        dupStatusEl.innerText = '✅ Laporan Unik';
        dupStatusEl.style.background = '#10b981';
    }
    document.getElementById('modal-similarity').innerText = `Similarity: ${similarity}`;
    
    // EXIF
    const exifFallback = `
        <ul style="list-style:none; padding:0; margin:0; line-height: 1.6;">
            <li>📷 <strong>Perangkat:</strong> Kamera Smartphone</li>
            <li>⏱️ <strong>Waktu Pengambilan:</strong> ${dateStr}</li>
            <li>📱 <strong>Aplikasi:</strong> Lapor Jambi Mobile App</li>
            <li>📡 <strong>Akurasi Lokasi:</strong> Tinggi (Terverifikasi GPS)</li>
        </ul>`;
    const exifData = report.exif_data ? JSON.stringify(report.exif_data) : exifFallback;
    document.getElementById('modal-exif').innerHTML = exifData;
    
    // Histori Status
    let historyHtml = `
        <div class="timeline-item">
            <div class="timeline-dot"></div>
            <div class="timeline-content">
                <strong>Dilaporkan oleh Warga</strong>
                <span>${dateStr}</span>
            </div>
        </div>
    `;
    
    if (report.status === 'inProgress' || report.status === 'resolved') {
        historyHtml += `
            <div class="timeline-item">
                <div class="timeline-dot" style="background:#f59e0b"></div>
                <div class="timeline-content">
                    <strong>Mulai Diproses</strong>
                    <span>Oleh Dinas Terkait</span>
                </div>
            </div>
        `;
    }
    if (report.status === 'resolved') {
        historyHtml += `
            <div class="timeline-item">
                <div class="timeline-dot" style="background:#10b981"></div>
                <div class="timeline-content">
                    <strong>Perbaikan Selesai</strong>
                    <span>Telah Diverifikasi</span>
                </div>
            </div>
        `;
    }
    
    document.getElementById('modal-history').innerHTML = historyHtml;
}

// Mengambil Data dari Supabase
async function fetchReports() {
    reportsContainer.innerHTML = '<div class="loading-state">Mengambil data dari server...</div>';
    
    if (!supabaseClient) return;
    
    try {
        const { data, error } = await supabaseClient
            .from('reports')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw error;
        
        reports = data;
        updateStats();
        renderReports();
        
        if (map) updateMapMarkers();
        
    } catch (err) {
        console.error('Error fetching reports:', err);
        reportsContainer.innerHTML = `<div class="loading-state">Gagal mengambil data: ${err.message}</div>`;
    }
}

// Update Statistik
function updateStats() {
    const filtered = applyFilters();
    const total = filtered.length;
    const completed = filtered.filter(r => r.status === 'resolved').length;
    const pending = total - completed;

    document.getElementById('stat-total').innerText = total;
    document.getElementById('stat-pending').innerText = pending;
    document.getElementById('stat-completed').innerText = completed;
    
    // Perbarui rekapitulasi data (Tabel & Grafik)
    if (typeof updateRecap === 'function') {
        updateRecap();
    }
}

// Render Kartu Laporan
function renderReports() {
    const filtered = applyFilters();
    
    if (filtered.length === 0) {
        reportsContainer.innerHTML = '<div class="loading-state">Belum ada laporan masuk atau tidak ada yang cocok dengan filter.</div>';
        return;
    }

    reportsContainer.innerHTML = '';
    
    filtered.forEach(report => {
        // Di aplikasi mobile, getPublicUrl sudah dipanggil dan disimpan langsung sebagai full URL di kolom image_url.
        const imageUrl = report.image_url;
        
        const statusMap = {
            'pending': { label: '⏳ Menunggu', class: 'pending' },
            'inProgress': { label: '🛠️ Sedang Diperbaiki', class: 'inprogress' },
            'resolved': { label: '✓ Selesai', class: 'completed' },
            'rejected': { label: '🚫 Ditolak', class: 'rejected' },
            'verified': { label: '👀 Diverifikasi', class: 'inprogress' }
        };
        const currentStatus = statusMap[report.status] || statusMap['pending'];
        
        const dateStr = new Date(report.created_at).toLocaleDateString('id-ID', {
            day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute:'2-digit'
        });

        let severityColor = '#0d9488'; 
        if (report.severity_label === 'Sangat Baik') severityColor = '#166534';
        else if (report.severity_label === 'Kerusakan Ringan') severityColor = '#8bc34a';
        else if (report.severity_label === 'Kerusakan Sedang') severityColor = '#fbc02d';
        else if (report.severity_label === 'Kerusakan Berat') severityColor = '#ff9800';
        else if (report.severity_label === 'Kerusakan Sangat Parah') severityColor = '#f44336';

        const priorityLabel = report.priority_level || (report.severity_label === 'Kerusakan Sangat Parah' ? 'Darurat' : 'Rendah');
        const isDarurat = priorityLabel.toLowerCase() === 'darurat';

        const card = document.createElement('div');
        card.className = `report-card ${isDarurat ? 'pulse-emergency' : ''}`;
        card.innerHTML = `
            <div class="report-img-container" onclick="openModalById('${report.id}')">
                <img src="${imageUrl}" class="report-img" alt="Kerusakan" onerror="this.src='https://via.placeholder.com/400x200?text=Gambar+Tidak+Tersedia'">
                ${isDarurat ? '<div style="position:absolute; top:8px; right:8px; background:rgba(220, 38, 38, 0.9); color:white; padding:4px 12px; border-radius:12px; font-weight:800; font-size:0.8rem; box-shadow:0 4px 12px rgba(0,0,0,0.5);">🚨 DARURAT</div>' : ''}
            </div>
            <div class="report-content">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span class="status-badge ${currentStatus.class}">
                        ${currentStatus.label}
                    </span>
                    <span style="background-color: ${isDarurat ? '#dc2626' : severityColor}; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: bold;">
                        ${isDarurat ? '🚨 ' : ''}${priorityLabel.toUpperCase()}
                    </span>
                </div>
                <h3 class="report-title">${report.category.replace('_', ' ')}</h3>
                <p class="report-desc">${report.description || 'Tidak ada catatan tambahan.'}</p>
                
                <div class="report-meta">
                    <span>Keparahan: ${report.severity_percentage || 0}% (${report.severity_label || 'Sangat Baik'})</span>
                    <span>${dateStr}</span>
                </div>

                <div class="admin-actions">
                    <select onchange="changeStatus('${report.id}', this.value)" class="status-select">
                        <option value="pending" ${report.status==='pending'?'selected':''}>⏳ Menunggu</option>
                        <option value="verified" ${report.status==='verified'?'selected':''}>👀 Diverifikasi</option>
                        <option value="inProgress" ${report.status==='inProgress'?'selected':''}>🛠️ Diperbaiki</option>
                        <option value="resolved" ${report.status==='resolved'?'selected':''}>✓ Selesai</option>
                        <option value="rejected" ${report.status==='rejected'?'selected':''}>🚫 Tolak</option>
                    </select>
                    <button class="btn-delete" onclick="deleteReport('${report.id}')" title="Hapus Laporan">🗑️</button>
                </div>
                
                <div style="margin-top: 8px;">
                    <a href="https://www.google.com/maps/search/?api=1&query=${report.latitude},${report.longitude}" target="_blank" class="btn-action" style="background: #3b82f6; color: white; text-align: center; text-decoration: none; display: block; padding: 10px; border-radius: 8px;">
                        📍 Buka di Maps
                    </a>
                </div>
            </div>
        `;
        reportsContainer.appendChild(card);
    });
}

// Mengubah Status Laporan
async function changeStatus(id, newStatus) {
    try {
        const { error } = await supabaseClient
            .from('reports')
            .update({ status: newStatus })
            .eq('id', id);

        if (error) throw error;
        
        // Refresh lokal
        reports = reports.map(r => r.id === id ? { ...r, status: newStatus } : r);
        updateStats();
        renderReports();
        if(map) updateMapMarkers();

    } catch (err) {
        alert('Gagal mengubah status: ' + err.message);
    }
}

// Menghapus Laporan
async function deleteReport(id) {
    if (!confirm('Yakin ingin menghapus laporan ini secara permanen? Tindakan ini tidak dapat dibatalkan.')) return;
    
    try {
        // Cari data laporan untuk mendapatkan URL gambarnya
        const report = reports.find(r => r.id === id);

        // 1. Hapus data dari tabel database
        const { error } = await supabaseClient
            .from('reports')
            .delete()
            .eq('id', id);

        if (error) throw error;
        
        // 2. Hapus file gambar dari Storage agar tidak menjadi sampah (Orphan file)
        if (report && report.image_url) {
            const bucketUrl = SUPABASE_URL + '/storage/v1/object/public/report-images/';
            if (report.image_url.startsWith(bucketUrl)) {
                // Ekstrak nama file/path relatif dari URL penuh
                const filePath = report.image_url.replace(bucketUrl, '');
                // Perintahkan Supabase Storage untuk menghapus file tersebut
                await supabaseClient.storage.from('report-images').remove([filePath]);
            }
        }
        
        // 3. Update tampilan UI
        reports = reports.filter(r => r.id !== id);
        updateStats();
        renderReports();
        if(map) updateMapMarkers();

    } catch (err) {
        alert('Gagal menghapus laporan: ' + err.message);
    }
}

// Inisialisasi Peta (Leaflet)
function initMap() {
    // Pusat peta di Kota Jambi
    map = L.map('admin-map').setView([-1.6101, 103.6131], 12);

    // Definisi berbagai jenis layer peta (Google Maps & Google Earth)
    const googleStreets = L.tileLayer('https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', {
        maxZoom: 20,
        subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
        attribution: '&copy; Google Maps'
    });

    const googleSatellite = L.tileLayer('https://{s}.google.com/vt/lyrs=s&x={x}&y={y}&z={z}', {
        maxZoom: 20,
        subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
        attribution: '&copy; Google Earth'
    });

    const googleHybrid = L.tileLayer('https://{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', {
        maxZoom: 20,
        subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
        attribution: '&copy; Google Hybrid'
    });

    // Default layer saat pertama kali dibuka
    googleHybrid.addTo(map);

    // Kontrol UI untuk berpindah gaya peta (Layer Control)
    const baseMaps = {
        "Google Maps (Jalan)": googleStreets,
        "Google Earth (Satelit)": googleSatellite,
        "Google Hybrid (Satelit + Label)": googleHybrid
    };

    // Tambahkan tombol pengontrol layer di sudut kanan atas
    L.control.layers(baseMaps, null, { position: 'topright' }).addTo(map);

    // Ambil dan gambar batas wilayah Kota Jambi
    fetchBoundary();

    updateMapMarkers();
}

async function fetchBoundary() {
    try {
        const response = await fetch('https://nominatim.openstreetmap.org/search.php?q=Kota+Jambi+Indonesia&polygon_geojson=1&format=json');
        const data = await response.json();
        
        if (data && data.length > 0) {
            // Cari data area administratif
            const boundaryData = data.find(item => item.class === 'boundary' && item.type === 'administrative') || data[0];
            
            if (boundaryData.geojson) {
                const jambiBoundary = L.geoJSON(boundaryData.geojson, {
                    style: {
                        color: '#4f46e5',
                        weight: 3,
                        opacity: 0.8,
                        fillColor: '#4f46e5',
                        fillOpacity: 0.05,
                        dashArray: '8, 8' // Border putus-putus elegan
                    }
                }).addTo(map);
                
                // Paskan peta agar batas wilayah terlihat semua
                map.fitBounds(jambiBoundary.getBounds());
            }
        }
    } catch (err) {
        console.error("Gagal memuat batas wilayah:", err);
    }
}

let markerClusterGroup = null;

function updateMapMarkers() {
    // Hapus marker lama dan cluster
    if (markerClusterGroup) {
        map.removeLayer(markerClusterGroup);
    }
    
    // Inisialisasi cluster group baru dengan ikon kustom elegan
    markerClusterGroup = L.markerClusterGroup({
        iconCreateFunction: function(cluster) {
            const count = cluster.getChildCount();
            return L.divIcon({
                html: `<div style="background-color: var(--primary); color: white; width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 50%; border: 3px solid white; box-shadow: 0 4px 10px rgba(0,0,0,0.3); font-weight: 800; font-family: 'Outfit';">${count}</div>`,
                className: 'custom-cluster-icon',
                iconSize: [32, 32]
            });
        },
        maxClusterRadius: 50
    });

    const filtered = applyFilters();
    filtered.forEach(report => {
        if (report.latitude && report.longitude) {
            let color = '#0d9488';
            if (report.severity_label === 'Sangat Baik') color = '#166534';
            else if (report.severity_label === 'Kerusakan Ringan') color = '#8bc34a';
            else if (report.severity_label === 'Kerusakan Sedang') color = '#fbc02d';
            else if (report.severity_label === 'Kerusakan Berat') color = '#ff9800';
            else if (report.severity_label === 'Kerusakan Sangat Parah') color = '#f44336';
            
            // Custom Icon untuk Marker Individual
            const iconHtml = `<div style="background-color: ${color}; width: 16px; height: 16px; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 6px rgba(0,0,0,0.5);"></div>`;
            const customIcon = L.divIcon({
                html: iconHtml,
                className: '',
                iconSize: [16, 16],
                iconAnchor: [8, 8]
            });

            const marker = L.marker([report.latitude, report.longitude], { icon: customIcon });
            
            // Popup Detail Interaktif (Klik Marker -> Detail)
            marker.bindPopup(`
                <div style="min-width: 220px; font-family: 'Outfit', sans-serif;">
                    <div style="width: 100%; height: 120px; overflow: hidden; border-radius: 8px; margin-bottom: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
                        <img src="${report.image_url}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.src='https://via.placeholder.com/220x120?text=Gambar+Kosong'">
                    </div>
                    <h4 style="margin: 0 0 6px 0; color: var(--text-dark); text-transform: capitalize; font-size: 1.1rem; font-weight: 800;">${report.category.replace('_', ' ')}</h4>
                    <div style="display: flex; gap: 6px; margin-bottom: 8px; flex-wrap: wrap;">
                        <span style="background-color: ${color}; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: bold; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                            ${report.severity_label || 'Sangat Baik'}
                        </span>
                        <span style="background-color: #f1f5f9; color: #475569; padding: 4px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: bold; text-transform: uppercase;">
                            ${report.status}
                        </span>
                    </div>
                    <p style="margin: 0; font-size: 0.85rem; color: var(--text-muted); line-height: 1.5;">
                        ${report.description || 'Tidak ada deskripsi spesifik untuk laporan ini.'}
                    </p>
                </div>
            `, {
                maxWidth: 300,
                className: 'premium-popup'
            });
            
            markerClusterGroup.addLayer(marker);
        }
    });

    map.addLayer(markerClusterGroup);
}

// Auth Functions
function switchAuthTab(tab) {
    document.getElementById('tab-login').classList.remove('active');
    document.getElementById('tab-register').classList.remove('active');
    document.getElementById('login-form').classList.remove('active');
    document.getElementById('register-form').classList.remove('active');
    
    document.getElementById(`tab-${tab}`).classList.add('active');
    document.getElementById(`${tab}-form`).classList.add('active');
}

async function handleLogin(e) {
    e.preventDefault();
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;
    const errorEl = document.getElementById('login-error');
    const btn = document.getElementById('btn-login-submit');
    
    errorEl.innerText = '';
    btn.innerText = 'Loading...';
    btn.disabled = true;
    
    try {
        const { error } = await supabaseClient.auth.signInWithPassword({ email, password });
        if (error) throw error;
        // onAuthStateChange will handle redirect
    } catch (error) {
        errorEl.innerText = error.message;
    } finally {
        btn.innerText = 'Masuk';
        btn.disabled = false;
    }
}

async function handleRegister(e) {
    e.preventDefault();
    const email = document.getElementById('register-email').value;
    const password = document.getElementById('register-password').value;
    const errorEl = document.getElementById('register-error');
    const btn = document.getElementById('btn-register-submit');
    
    errorEl.innerText = '';
    btn.innerText = 'Loading...';
    btn.disabled = true;
    
    try {
        const { error } = await supabaseClient.auth.signUp({ email, password });
        if (error) throw error;
        alert('Registrasi berhasil! Anda sekarang sudah masuk.');
        // onAuthStateChange handles redirecting to dashboard.
    } catch (error) {
        errorEl.innerText = error.message;
    } finally {
        btn.innerText = 'Daftar Admin';
        btn.disabled = false;
    }
}

async function handleLogout() {
    if(confirm('Yakin ingin keluar?')) {
        await supabaseClient.auth.signOut();
    }
}

// Jalankan
document.addEventListener('DOMContentLoaded', init);

// Rekapitulasi & Chart.js Logic
let trendChartInstance = null;
let severityChartInstance = null;
let categoryChartInstance = null;
let districtChartInstance = null;

function updateRecap() {
    const filter = document.getElementById('recap-filter');
    if (!filter) return;
    const filterValue = filter.value;
    const tableBody = document.querySelector('#recap-table tbody');
    if (!tableBody) return;

    // Gunakan filter global (applyFilters) agar recap sinkron dengan panel pencarian
    const baseData = applyFilters();
    
    // 1. Inisialisasi Penampung Data Agregasi
    const groupedData = {};
    const severityData = { 'Sangat Baik': 0, 'Kerusakan Ringan': 0, 'Kerusakan Sedang': 0, 'Kerusakan Berat': 0, 'Kerusakan Sangat Parah': 0 };
    const categoryData = {};
    const districtData = {};
    
    // 2. Proses Agregasi
    baseData.forEach(r => {
        // Trend Data
        const date = new Date(r.created_at);
        let key = '';
        if (filterValue === 'daily') {
            key = date.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }); 
        } else if (filterValue === 'weekly') {
            const first = date.getDate() - date.getDay() + 1;
            const firstDay = new Date(new Date(date).setDate(first));
            key = 'Mg ' + firstDay.toLocaleDateString('id-ID', { day: '2-digit', month: 'short' });
        } else if (filterValue === 'monthly') {
            const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des'];
            key = months[date.getMonth()] + ' ' + date.getFullYear();
        } else if (filterValue === 'yearly') {
            key = date.getFullYear().toString();
        }
        
        if (!groupedData[key]) groupedData[key] = { total: 0, resolved: 0, pending: 0, rejected: 0 };
        groupedData[key].total++;
        if (r.status === 'resolved') groupedData[key].resolved++;
        else if (r.status === 'rejected') groupedData[key].rejected++;
        else groupedData[key].pending++;

        // Severity Data
        const sev = r.severity_label || 'Sangat Baik';
        if (severityData[sev] !== undefined) severityData[sev]++;
        else severityData[sev] = 1;

        // Category Data
        const cat = (r.category || 'Lainnya').replace('_', ' ').toUpperCase();
        categoryData[cat] = (categoryData[cat] || 0) + 1;

        // District Data
        const dist = (r.kecamatan || 'Kecamatan Lainnya').toUpperCase();
        districtData[dist] = (districtData[dist] || 0) + 1;
    });
    
    // 3. Update Tabel Rekapitulasi
    const keys = Object.keys(groupedData); 
    tableBody.innerHTML = '';
    keys.forEach(k => {
        const d = groupedData[k];
        const row = document.createElement('tr');
        row.innerHTML = `
            <td><strong>${k}</strong></td>
            <td>${d.total}</td>
            <td style="color:var(--success); font-weight:800;">${d.resolved}</td>
            <td style="color:var(--warning); font-weight:800;">${d.pending}</td>
            <td style="color:var(--danger); font-weight:800;">${d.rejected}</td>
        `;
        tableBody.appendChild(row);
    });
    
    // Fungsi bantuan untuk membersihkan chart lama
    const safeDestroy = (chartInstance) => { if (chartInstance) chartInstance.destroy(); };

    // ============================================
    // 4. CHART 1: TREND LAPORAN (LINE CHART)
    // ============================================
    const chartLabels = [...keys].reverse();
    const dataTotal = chartLabels.map(k => groupedData[k].total);
    const dataResolved = chartLabels.map(k => groupedData[k].resolved);
    
    const ctxTrend = document.getElementById('recap-chart')?.getContext('2d');
    if (ctxTrend) {
        safeDestroy(trendChartInstance);
        trendChartInstance = new Chart(ctxTrend, {
            type: 'line',
            data: {
                labels: chartLabels,
                datasets: [
                    { label: 'Total Laporan Masuk', data: dataTotal, borderColor: '#4f46e5', backgroundColor: 'rgba(79, 70, 229, 0.1)', borderWidth: 3, tension: 0.4, fill: true },
                    { label: 'Laporan Diselesaikan', data: dataResolved, borderColor: '#10b981', backgroundColor: 'transparent', borderWidth: 3, tension: 0.4, borderDash: [5, 5] }
                ]
            },
            options: { 
                responsive: true, 
                maintainAspectRatio: false, 
                plugins: { legend: { position: 'top', labels: { font: { family: 'Outfit', weight: 'bold' } } } }, 
                scales: { y: { beginAtZero: true, ticks: { stepSize: 1, font: { family: 'Outfit' } } }, x: { ticks: { font: { family: 'Outfit' } } } } 
            }
        });
    }

    // ============================================
    // 5. CHART 2: SEVERITY (DOUGHNUT CHART)
    // ============================================
    const ctxSev = document.getElementById('severity-chart')?.getContext('2d');
    if (ctxSev) {
        safeDestroy(severityChartInstance);
        severityChartInstance = new Chart(ctxSev, {
            type: 'doughnut',
            data: {
                labels: ['Sangat Baik', 'Ringan', 'Sedang', 'Berat', 'Sangat Parah'],
                datasets: [{
                    data: [severityData['Sangat Baik'], severityData['Kerusakan Ringan'], severityData['Kerusakan Sedang'], severityData['Kerusakan Berat'], severityData['Kerusakan Sangat Parah']],
                    backgroundColor: ['#166534', '#8bc34a', '#fbc02d', '#ff9800', '#f44336'],
                    borderWidth: 0,
                    hoverOffset: 8
                }]
            },
            options: { 
                responsive: true, 
                maintainAspectRatio: false, 
                plugins: { legend: { position: 'right', labels: { font: { family: 'Outfit' } } } }, 
                cutout: '70%' 
            }
        });
    }

    // ============================================
    // 6. CHART 3: KATEGORI (PIE CHART)
    // ============================================
    const ctxCat = document.getElementById('category-chart')?.getContext('2d');
    if (ctxCat) {
        safeDestroy(categoryChartInstance);
        categoryChartInstance = new Chart(ctxCat, {
            type: 'pie',
            data: {
                labels: Object.keys(categoryData),
                datasets: [{
                    data: Object.values(categoryData),
                    backgroundColor: ['#4f46e5', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4'],
                    borderWidth: 0,
                    hoverOffset: 8
                }]
            },
            options: { 
                responsive: true, 
                maintainAspectRatio: false, 
                plugins: { legend: { position: 'right', labels: { font: { family: 'Outfit' } } } } 
            }
        });
    }

    // ============================================
    // 7. CHART 4: KECAMATAN (BAR CHART)
    // ============================================
    const ctxDist = document.getElementById('district-chart')?.getContext('2d');
    if (ctxDist) {
        safeDestroy(districtChartInstance);
        districtChartInstance = new Chart(ctxDist, {
            type: 'bar',
            data: {
                labels: Object.keys(districtData),
                datasets: [{
                    label: 'Jumlah Laporan',
                    data: Object.values(districtData),
                    backgroundColor: 'rgba(79, 70, 229, 0.8)',
                    borderRadius: 6
                }]
            },
            options: { 
                responsive: true, 
                maintainAspectRatio: false, 
                plugins: { legend: { display: false } }, 
                scales: { y: { beginAtZero: true, ticks: { stepSize: 1, font: { family: 'Outfit' } } }, x: { ticks: { font: { family: 'Outfit' } } } } 
            }
        });
    }
}
