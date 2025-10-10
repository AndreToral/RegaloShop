import React, { createContext, useContext, useEffect, useMemo, useReducer } from 'react';

const CartContext = createContext();
const CART_STORAGE_KEY = 'regaloshop-cart';

const initialState = {
  items: [],
  isCartOpen: false,
};

function cartReducer(state, action) {
  switch (action.type) {
    case 'INITIALIZE':
      return {
        ...state,
        ...action.payload,
      };
    case 'ADD_ITEM': {
      const { product, quantity } = action.payload;
      const existing = state.items.find((item) => item.product.id === product.id);

      let updatedItems;
      if (existing) {
        updatedItems = state.items.map((item) =>
          item.product.id === product.id
            ? { ...item, quantity: item.quantity + quantity }
            : item
        );
      } else {
        updatedItems = [...state.items, { product, quantity }];
      }

      return { ...state, items: updatedItems, isCartOpen: true };
    }
    case 'REMOVE_ITEM':
      return {
        ...state,
        items: state.items.filter((item) => item.product.id !== action.payload),
      };
    case 'UPDATE_QUANTITY': {
      const { productId, quantity } = action.payload;
      return {
        ...state,
        items: state.items
          .map((item) =>
            item.product.id === productId ? { ...item, quantity } : item
          )
          .filter((item) => item.quantity > 0),
      };
    }
    case 'CLEAR_CART':
      return { ...state, items: [] };
    case 'TOGGLE_CART':
      return { ...state, isCartOpen: action.payload ?? !state.isCartOpen };
    default:
      return state;
  }
}

function persistState(state) {
  if (typeof window === 'undefined') return;
  const payload = {
    items: state.items,
  };
  window.localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(payload));
}

export function CartProvider({ children }) {
  const [state, dispatch] = useReducer(cartReducer, initialState);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const stored = window.localStorage.getItem(CART_STORAGE_KEY);
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        if (Array.isArray(parsed.items)) {
          dispatch({ type: 'INITIALIZE', payload: { ...initialState, ...parsed } });
        }
      } catch (error) {
        console.error('Error al leer el carrito', error);
      }
    }
  }, []);

  useEffect(() => {
    persistState(state);
  }, [state.items]);

  const value = useMemo(() => {
    const items = state.items;
    const cartCount = items.reduce((acc, item) => acc + item.quantity, 0);
    const cartTotal = items
      .reduce((acc, item) => acc + item.product.price * item.quantity, 0)
      .toFixed(2);

    return {
      items,
      cartCount,
      cartTotal: Number(cartTotal),
      isCartOpen: state.isCartOpen,
      addItem: (product, quantity = 1) =>
        dispatch({ type: 'ADD_ITEM', payload: { product, quantity } }),
      removeItem: (productId) =>
        dispatch({ type: 'REMOVE_ITEM', payload: productId }),
      updateQuantity: (productId, quantity) =>
        dispatch({ type: 'UPDATE_QUANTITY', payload: { productId, quantity } }),
      clearCart: () => dispatch({ type: 'CLEAR_CART' }),
      toggleCart: (open) => dispatch({ type: 'TOGGLE_CART', payload: open }),
    };
  }, [state.items, state.isCartOpen]);

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart() {
  const context = useContext(CartContext);
  if (!context) {
    throw new Error('useCart debe usarse dentro de un CartProvider');
  }
  return context;
}
