function CartItem({ item, onRemove, onQuantityChange }) {
  const { product, quantity } = item;

  return (
    <li className="cart-item">
      <div className="cart-item__thumb" aria-hidden="true">
        {product.image ? (
          <img src={product.image} alt={product.name} loading="lazy" />
        ) : (
          <span>{product.name.charAt(0)}</span>
        )}
      </div>
      <div className="cart-item__info">
        <h4>{product.name}</h4>
        <p>${product.price.toFixed(2)} - {product.category}</p>
        <small>Stock: {product.stock}</small>
      </div>
      <div className="cart-item__actions">
        <label className="cart-item__quantity" htmlFor={`qty-${product.id}`}>
          Cantidad
          <input
            id={`qty-${product.id}`}
            type="number"
            min="1"
            max={product.stock}
            value={quantity}
            onChange={(event) => onQuantityChange(Number(event.target.value))}
          />
        </label>
        <button className="ghost" onClick={onRemove}>
          Quitar
        </button>
      </div>
    </li>
  );
}

export default CartItem;
