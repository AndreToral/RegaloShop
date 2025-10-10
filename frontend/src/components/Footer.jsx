function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="app-footer">
      <div className="container">
        <p>
          {year} RegaloShop - Hecho con carino para sorprender en cada ocasion.
        </p>
        <p className="footer-contact">
          <span>Necesitas ayuda? Escribenos a</span>
          <a href="mailto:hola@regaloshop.com">hola@regaloshop.com</a>
        </p>
      </div>
    </footer>
  );
}

export default Footer;
