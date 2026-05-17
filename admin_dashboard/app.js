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
const viewReports = document.getElementById('reports-view');
const viewMap = document.getElementById('map-view');
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
    await fetchReports();
}

// Navigasi
function setupNavigation() {
    navReports.addEventListener('click', (e) => {
        e.preventDefault();
        navReports.classList.add('active');
        navMap.classList.remove('active');
        viewReports.classList.add('active');
        viewMap.classList.remove('active');
    });

    navMap.addEventListener('click', (e) => {
        e.preventDefault();
        navMap.classList.add('active');
        navReports.classList.remove('active');
        viewMap.classList.add('active');
        viewReports.classList.remove('active');
        
        // Inisialisasi peta jika belum ada
        if (!map) {
            initMap();
        } else {
            map.invalidateSize(); // Perbaiki ukuran peta saat ditab
        }
    });

    btnRefresh.addEventListener('click', () => {
        fetchReports();
    });
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
    map = L.map('admin-map').setView([-1.6101, 103.6131], 13);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://carto.com/">CARTO</a>'
    }).addTo(map);

    updateMapMarkers();
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

// Jalankan
document.addEventListener('DOMContentLoaded', init);
