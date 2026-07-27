document.addEventListener('DOMContentLoaded', () => {
  const header = document.getElementById('siteHeader');
  const navToggle = document.getElementById('navToggle');
  const nav = document.getElementById('nav');
  const navBackdrop = document.getElementById('navBackdrop');

  window.addEventListener('scroll', () => {
    header.classList.toggle('scrolled', window.scrollY > 10);
  });

  const closeNav = () => {
    nav.classList.remove('open');
    navBackdrop.classList.remove('open');
  };

  navToggle.addEventListener('click', () => {
    nav.classList.toggle('open');
    navBackdrop.classList.toggle('open');
  });

  navBackdrop.addEventListener('click', closeNav);

  nav.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', closeNav);
  });

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.15 });

  document.querySelectorAll('.fade-in').forEach(el => observer.observe(el));

  const reviewForm = document.getElementById('reviewForm');
  const reviewConfirmation = document.getElementById('reviewConfirmation');
  if (reviewForm) {
    reviewForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const nom = reviewForm.nom.value;
      const note = reviewForm.note.value;
      const message = reviewForm.message.value;
      const sujet = encodeURIComponent(`Nouvel avis sur BC Studio — ${nom}`);
      const corps = encodeURIComponent(`Nom : ${nom}\nNote : ${note}/5\nAvis : ${message}`);
      window.location.href = `mailto:cokgulb@gmail.com?subject=${sujet}&body=${corps}`;
      reviewConfirmation.classList.add('visible');
      reviewForm.reset();
    });
  }
});
