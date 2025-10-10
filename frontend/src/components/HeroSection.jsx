function HeroSection({ onShopNow }) {
  return (
    <section className="hero">
      <div className="container hero-content">
        <div className="hero-text">
          <h2>Regalos con estilo, ropa con personalidad</h2>
          <p>
            Explora colecciones cuidadas de detalles especiales y prendas
            seleccionadas para sorprender y lucir increible.
          </p>
          <div className="hero-actions">
            <a className="primary" href="#catalogo">Ver catalogo</a>
            <button className="ghost" onClick={onShopNow}>
              Ver carrito
            </button>
          </div>
        </div>
        <div className="hero-highlight">
          <p>Envio gratis desde $80</p>
          <p>Personaliza tus regalos con notas dedicadas</p>
        </div>
      </div>
    </section>
  );
}

export default HeroSection;
