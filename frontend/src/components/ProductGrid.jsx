import ProductCard from './ProductCard.jsx';

function ProductGrid({ products, onSelectProduct }) {
  return (
    <div className="product-grid">
      {products.map((product) => (
        <ProductCard
          key={product.id}
          product={product}
          onViewDetails={() => onSelectProduct(product)}
        />
      ))}
    </div>
  );
}

export default ProductGrid;
