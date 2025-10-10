import { useEffect, useMemo, useState } from 'react';
import { apiClient } from '../api/client';

export function useProducts(filters) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const queryParams = useMemo(() => {
    if (!filters) return {};
    const params = { ...filters };
    if (filters.priceRange) {
      params.minPrice = filters.priceRange[0];
      params.maxPrice = filters.priceRange[1];
      delete params.priceRange;
    }
    return params;
  }, [filters]);

  useEffect(() => {
    let isMounted = true;
    async function fetchProducts() {
      try {
        setLoading(true);
        setError(null);
        const data = await apiClient.getProducts(queryParams);
        if (isMounted) {
          setProducts(data);
        }
      } catch (err) {
        if (isMounted) {
          setError(err.message || 'No se pudieron cargar los productos');
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchProducts();

    return () => {
      isMounted = false;
    };
  }, [JSON.stringify(queryParams)]);

  return { products, loading, error };
}
