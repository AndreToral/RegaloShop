import { useCart } from '../context/CartContext.jsx';
import CartItem from './CartItem.jsx';

function CartDrawer({ isOpen, onClose }) {
  const { items, cartTotal, cartCount, removeItem, updateQuantity } = useCart();

  return (
    <div
      className={`cart-overlay ${isOpen ? 'open' : ''}`}
      onClick={onClose}
      role="presentation"
    >
      <div className="cart-drawer" onClick={(event) => event.stopPropagation()}>
        <header className="cart-header">
          <h2>Tu carrito ({cartCount})</h2>
          <button className="ghost" onClick={onClose}>
            Cerrar
          </button>
        </header>
        <div className="cart-body">
          {items.length === 0 ? (
            <p className="cart-empty">Todavia no agregaste productos.</p>
          ) : (
            <ul className="cart-items">
              {items.map((item) => (
                <CartItem
                  key={item.product.id}
                  item={item}
                  onRemove={() => removeItem(item.product.id)}
                  onQuantityChange={(quantity) =>
                    updateQuantity(item.product.id, quantity)
                  }
                />
              ))}
            </ul>
          )}
        </div>
        <footer className="cart-footer">
          <div className="cart-summary">
            <span>Total</span>
            <strong>${cartTotal.toFixed(2)}</strong>
          </div>
          <a
            className="primary"
            href="#/checkout"
            onClick={onClose}
            aria-disabled={items.length === 0}
            style={{ pointerEvents: items.length === 0 ? 'none' : 'auto', textAlign: 'center' }}
          >
            Ir a pagar
          </a>
        </footer>
      </div>
    </div>
  );
}

export default CartDrawer;
