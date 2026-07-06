// Minimal JS to wire download buttons and modal
const downloadAndroid = document.getElementById('download-android');
const downloadIos = document.getElementById('download-ios');
const ctaAndroid = document.getElementById('cta-android');
const ctaIos = document.getElementById('cta-ios');
const modal = document.getElementById('download-modal');
const modalClose = document.getElementById('modal-close');
const modalAndroid = document.getElementById('modal-android');
const modalIos = document.getElementById('modal-ios');

function openModal() { modal.classList.remove('hidden'); modal.classList.add('flex'); }
function closeModal() { modal.classList.remove('flex'); modal.classList.add('hidden'); }

[downloadAndroid, ctaAndroid, modalAndroid].forEach(el=>{
  if(!el) return;
  el.addEventListener('click', (e)=>{
    e.preventDefault();
    // Replace URL below with your hosted APK path
    const apkUrl = '/downloads/staynest.apk';
    window.location.href = apkUrl;
  });
});

[downloadIos, ctaIos, modalIos].forEach(el=>{
  if(!el) return;
  el.addEventListener('click', (e)=>{
    e.preventDefault();
    // iOS distribution typically uses TestFlight or App Store links
    // show modal with options by default
    openModal();
  });
});

if(modalClose) modalClose.addEventListener('click', (e)=>{ e.preventDefault(); closeModal(); });

// defensive: close modal on background click
modal.addEventListener('click', (ev)=>{
  if(ev.target === modal) closeModal();
});
