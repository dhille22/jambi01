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

// Modal Gambar
function setupModal() {
    closeBtn.onclick = () => modal.style.display = "none";
    window.onclick = (e) => {
        if (e.target == modal) modal.style.display = "none";
    }
}

function openModal(imgUrl) {
    modal.style.display = "block";
    modalImg.src = imgUrl;
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
    const total = reports.length;
    const completed = reports.filter(r => r.status === 'resolved').length;
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
    if (reports.length === 0) {
        reportsContainer.innerHTML = '<div class="loading-state">Belum ada laporan masuk.</div>';
        return;
    }

    reportsContainer.innerHTML = '';
    
    reports.forEach(report => {
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

        const card = document.createElement('div');
        card.className = 'report-card';
        card.innerHTML = `
            <div class="report-img-container" onclick="openModal('${imageUrl}')">
                <img src="${imageUrl}" class="report-img" alt="Kerusakan" onerror="this.src='https://via.placeholder.com/400x200?text=Gambar+Tidak+Tersedia'">
            </div>
            <div class="report-content">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span class="status-badge ${currentStatus.class}">
                        ${currentStatus.label}
                    </span>
                    <span style="background-color: ${severityColor}; color: white; padding: 4px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: bold;">
                        ${report.priority_level || 'Rendah'}
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

function updateMapMarkers() {
    // Hapus marker lama
    markers.forEach(m => map.removeLayer(m));
    markers = [];

    reports.forEach(report => {
        if (report.latitude && report.longitude) {
            let color = '#0d9488';
            if (report.severity_label === 'Sangat Baik') color = '#166534';
            else if (report.severity_label === 'Kerusakan Ringan') color = '#8bc34a';
            else if (report.severity_label === 'Kerusakan Sedang') color = '#fbc02d';
            else if (report.severity_label === 'Kerusakan Berat') color = '#ff9800';
            else if (report.severity_label === 'Kerusakan Sangat Parah') color = '#f44336';
            
            // Custom Icon
            const iconHtml = `<div style="background-color: ${color}; width: 14px; height: 14px; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 4px rgba(0,0,0,0.5);"></div>`;
            const customIcon = L.divIcon({
                html: iconHtml,
                className: '',
                iconSize: [14, 14],
                iconAnchor: [7, 7]
            });

            const marker = L.marker([report.latitude, report.longitude], { icon: customIcon }).addTo(map);
            
            marker.bindPopup(`
                <b>${report.category.replace('_', ' ')}</b><br>
                Keparahan: ${report.severity_label || 'Sangat Baik'} (${report.severity_percentage || 0}%)<br>
                Status: ${report.status}<br>
                ${report.description || ''}
            `);
            
            markers.push(marker);
        }
    });
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
let recapChartInstance = null;

function updateRecap() {
    const filter = document.getElementById('recap-filter');
    if (!filter) return;
    const filterValue = filter.value;
    const tableBody = document.querySelector('#recap-table tbody');
    if (!tableBody) return;
    
    const groupedData = {};
    
    // reports sudah diurutkan dari yang terbaru (karena order('created_at', { ascending: false }))
    reports.forEach(r => {
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
        
        if (!groupedData[key]) {
            groupedData[key] = { total: 0, resolved: 0, pending: 0, rejected: 0 };
        }
        
        groupedData[key].total++;
        if (r.status === 'resolved') groupedData[key].resolved++;
        else if (r.status === 'rejected') groupedData[key].rejected++;
        else groupedData[key].pending++;
    });
    
    const keys = Object.keys(groupedData); 
    
    // Update Tabel
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
    
    // Update Chart (balik arah agar yang terlama di kiri, terbaru di kanan)
    const chartLabels = [...keys].reverse();
    const dataTotal = chartLabels.map(k => groupedData[k].total);
    const dataResolved = chartLabels.map(k => groupedData[k].resolved);
    
    const canvas = document.getElementById('recap-chart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    
    if (recapChartInstance) {
        recapChartInstance.destroy();
    }
    
    recapChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: chartLabels,
            datasets: [
                {
                    label: 'Total Laporan',
                    data: dataTotal,
                    borderColor: '#4f46e5',
                    backgroundColor: 'rgba(79, 70, 229, 0.1)',
                    borderWidth: 3,
                    tension: 0.4,
                    fill: true
                },
                {
                    label: 'Selesai',
                    data: dataResolved,
                    borderColor: '#10b981',
                    backgroundColor: 'transparent',
                    borderWidth: 3,
                    tension: 0.4,
                    borderDash: [5, 5]
                }
            ]
        },
        options: {
            responsive: true,
            plugins: { 
                legend: { position: 'top', labels: { font: { family: 'Outfit', weight: 'bold' } } }
            },
            scales: { 
                y: { beginAtZero: true, ticks: { stepSize: 1, font: { family: 'Outfit' } } },
                x: { ticks: { font: { family: 'Outfit', weight: '600' } } }
            }
        }
    });
}
