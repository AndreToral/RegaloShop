function Header({ cartCount, onCartClick }) {
  return (
    <header className="app-header">
      <div className="container">
        <div className="brand">
          <span className="brand-logo">RS</span>
          <div>
            <h1>RegaloShop</h1>
            <p>Detalles y estilo para cada ocasion</p>
          </div>
        </div>
        <nav className="header-actions">
          <button className="cart-button" onClick={onCartClick}>
            <span>Carrito</span>
            <span className="cart-badge">{cartCount}</span>
          </button>
        </nav>
      </div>
    </header>
  );
}

export default Header;
