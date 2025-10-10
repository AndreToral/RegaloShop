import { API_BASE_URL } from '../config';

async function request(path, options = {}) {
  const config = {
    headers: {
      'Content-Type': 'application/json',
    },
    ...options,
  };

  const response = await fetch(`${API_BASE_URL}${path}`, config);
  if (!response.ok) {
    const errorBody = await response.json().catch(() => ({}));
    const message = errorBody.message || 'Error en la solicitud';
    throw new Error(message);
  }
  return response.json();
}

function buildQueryString(params) {
  if (!params) return '';
  const searchParams = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.append(key, value);
    }
  });

  const query = searchParams.toString();
  return query ? `?${query}` : '';
}

export const apiClient = {
  async getProducts(params) {
    const query = buildQueryString(params);
    return request(`/products${query}`);
  },
  async getProduct(id) {
    return request(`/products/${id}`);
  },
  async getCategories() {
    return request('/categories');
  },
  async createOrder(payload) {
    return request('/orders', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  },
};
