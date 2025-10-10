import { useEffect, useMemo, useState } from 'react';
import Header from './components/Header.jsx';
import HeroSection from './components/HeroSection.jsx';
import FiltersBar from './components/FiltersBar.jsx';
import ProductGrid from './components/ProductGrid.jsx';
import CartDrawer from './components/CartDrawer.jsx';
import StatusBanner from './components/StatusBanner.jsx';
import ProductModal from './components/ProductModal.jsx';
import Footer from './components/Footer.jsx';
import CheckoutPage from './pages/CheckoutPage.jsx';
import LoadingSpinner from './components/LoadingSpinner.jsx';
import { useCart } from './context/CartContext.jsx';
import { useProducts } from './hooks/useProducts.js';
import { apiClient } from './api/client.js';

function App() {
  const [route, setRoute] = useState(window.location.hash || '#/');
  const [filters, setFilters] = useState({
    search: '',
    category: '',
    sort: 'price-asc',
    priceRange: [0, 100],
  });
  const [categories, setCategories] = useState([]);
  const [categoryError, setCategoryError] = useState(null);
  const [selectedProduct, setSelectedProduct] = useState(null);

  const productQuery = useMemo(
    () => ({
      search: filters.search || undefined,
      category: filters.category || undefined,
      sort: filters.sort || undefined,
      priceRange: filters.priceRange,
    }),
    [filters]
  );

  const { products, loading, error } = useProducts(productQuery);
  const { cartCount, toggleCart, isCartOpen } = useCart();

  useEffect(() => {
    const onHash = () => setRoute(window.location.hash || '#/');
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  useEffect(() => {
    let active = true;
    async function loadCategories() {
      try {
        const data = await apiClient.getCategories();
        if (active) {
          setCategories(data);
          setCategoryError(null);
        }
      } catch (err) {
        if (active) {
          setCategoryError(err.message || 'No se pudieron cargar las categorias');
        }
      }
    }
    loadCategories();
    return () => {
      active = false;
    };
  }, []);

  const handleFilterChange = (changes) => {
    setFilters((prev) => ({
      ...prev,
      ...changes,
    }));
  };

  const handleResetFilters = () => {
    setFilters({
      search: '',
      category: '',
      sort: 'price-asc',
      priceRange: [0, 100],
    });
  };

  const handleSelectProduct = (product) => {
    setSelectedProduct(product);
  };

  return (
    <div className="app-shell">
      <Header cartCount={cartCount} onCartClick={() => toggleCart(true)} />
      <main>
        {route.startsWith('#/checkout') ? (
          <CheckoutPage />
        ) : (
          <>
            <HeroSection onShopNow={() => toggleCart(true)} />
            <section id="catalogo" className="catalog-section">
              <FiltersBar
                filters={filters}
                categories={categories}
                onChange={handleFilterChange}
                onReset={handleResetFilters}
                error={categoryError}
              />
              {loading && <LoadingSpinner message="Cargando productos" />}
              {error && !loading && <StatusBanner type="error" message={error} />}
              {!loading && !error && products.length === 0 && (
                <StatusBanner
                  type="info"
                  message="No encontramos productos que coincidan con la busqueda. Ajusta los filtros."
                />
              )}
              {!loading && !error && products.length > 0 && (
                <ProductGrid products={products} onSelectProduct={handleSelectProduct} />
              )}
            </section>
          </>
        )}
      </main>
      <Footer />
      {!route.startsWith('#/checkout') && (
        <CartDrawer isOpen={isCartOpen} onClose={() => toggleCart(false)} />
      )}
      <ProductModal
        product={selectedProduct}
        onClose={() => setSelectedProduct(null)}
      />
    </div>
  );
}

export default App;
