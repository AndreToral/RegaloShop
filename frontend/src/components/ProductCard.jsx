import { useCart } from '../context/CartContext.jsx';

function ProductCard({ product, onViewDetails }) {
  const { addItem } = useCart();

  return (
    <article className="product-card">
      <div className="product-card__tag">{product.category}</div>
      <div className="product-card__image" aria-hidden="true">
        {product.image ? (
          <img src={product.image} alt={product.name} loading="lazy" />
        ) : (
          <span>{product.name.charAt(0)}</span>
        )}
      </div>
      <div className="product-card__body">
        <h3>{product.name}</h3>
        <p className="product-card__description">{product.description}</p>
        <div className="product-card__price">
          <strong>${product.price.toFixed(2)}</strong>
          <span>{product.stock} disponibles</span>
        </div>
        <div className="product-card__actions">
          <button className="primary" onClick={() => addItem(product)}>
            Agregar al carrito
          </button>
          <button className="ghost" onClick={onViewDetails}>
            Ver detalles
          </button>
        </div>
      </div>
    </article>
  );
}

export default ProductCard;
