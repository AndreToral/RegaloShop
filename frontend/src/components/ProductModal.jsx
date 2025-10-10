import { useCart } from '../context/CartContext.jsx';

function ProductModal({ product, onClose }) {
  const { addItem } = useCart();

  if (!product) return null;

  const handleAddToCart = () => {
    addItem(product);
    onClose();
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <article
        className="modal"
        onClick={(event) => event.stopPropagation()}
      >
        <header>
          <h2>{product.name}</h2>
          <button className="ghost" onClick={onClose}>
            Cerrar
          </button>
        </header>
        <div className="modal-body">
          <div className="modal-image" aria-hidden="true">
            {product.image ? (
              <img src={product.image} alt={product.name} loading="lazy" />
            ) : (
              <span>{product.name.charAt(0)}</span>
            )}
          </div>
          <div className="modal-details">
            <p>{product.description}</p>
            <p className="modal-price">${product.price.toFixed(2)}</p>
            <p className="modal-stock">Stock disponible: {product.stock}</p>
            <div className="modal-tags">
              {product.tags?.map((tag) => (
                <span key={tag} className="tag">{tag}</span>
              ))}
            </div>
          </div>
        </div>
        <footer>
          <button className="primary" onClick={handleAddToCart}>
            Agregar al carrito
          </button>
        </footer>
      </article>
    </div>
  );
}

export default ProductModal;
