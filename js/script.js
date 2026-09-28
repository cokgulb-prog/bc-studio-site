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

  const FORM_ENDPOINT = 'https://formsubmit.co/ajax/cokgulb@gmail.com';

  const sendForm = async (data) => {
    const res = await fetch(FORM_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify(data)
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok || json.success === 'false' || json.success === false) throw new Error(json.message || 'Erreur');
    return json;
  };

  const contactForm = document.getElementById('contactForm');
  const contactConfirmation = document.getElementById('contactConfirmation');
  if (contactForm) {
    contactForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (contactForm._honey.value) return;
      const button = contactForm.querySelector('button');
      button.disabled = true;
      button.textContent = 'Envoi en cours…';
      contactConfirmation.classList.remove('visible', 'error');
      try {
        await sendForm({
          _subject: `Nouvelle demande BC Studio — ${contactForm.nom.value}`,
          _template: 'table',
          _captcha: 'false',
          _replyto: contactForm.email.value,
          Nom: contactForm.nom.value,
          Email: contactForm.email.value,
          'Téléphone': contactForm.telephone.value || '—',
          Message: contactForm.message.value
        });
        contactConfirmation.textContent = 'Merci ! Votre demande a bien été envoyée. Je vous réponds sous 24 à 48 h.';
        contactForm.reset();
      } catch (err) {
        contactConfirmation.textContent = "Oups, l'envoi n'a pas fonctionné. Écrivez-moi directement à cokgulb@gmail.com.";
        contactConfirmation.classList.add('error');
      }
      contactConfirmation.classList.add('visible');
      button.disabled = false;
      button.textContent = 'Envoyer ma demande';
    });
  }

  const reviewForm = document.getElementById('reviewForm');
  const reviewConfirmation = document.getElementById('reviewConfirmation');
  if (reviewForm) {
    reviewForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const button = reviewForm.querySelector('button');
      button.disabled = true;
      reviewConfirmation.classList.remove('visible', 'error');
      try {
        await sendForm({
          _subject: `Nouvel avis sur BC Studio — ${reviewForm.nom.value}`,
          _template: 'table',
          _captcha: 'false',
          Nom: reviewForm.nom.value,
          Note: `${reviewForm.note.value}/5`,
          Avis: reviewForm.message.value
        });
        reviewConfirmation.textContent = 'Merci pour votre avis ! Il sera publié après relecture.';
        reviewForm.reset();
      } catch (err) {
        reviewConfirmation.textContent = "Oups, l'envoi n'a pas fonctionné. Réessayez dans un instant.";
        reviewConfirmation.classList.add('error');
      }
      reviewConfirmation.classList.add('visible');
      button.disabled = false;
    });
  }
});
