import { useState } from 'react';
import { useCart } from '../context/CartContext.jsx';
import { apiClient } from '../api/client.js';
import CheckoutForm from '../components/CheckoutForm.jsx';

function CheckoutPage() {
  const { items, cartTotal, clearCart } = useCart();
  const [status, setStatus] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleCheckout = async (formData) => {
    try {
      setIsSubmitting(true);
      setStatus(null);
      if (items.length === 0) {
        setStatus({ type: 'error', message: 'Tu carrito está vacío.' });
        return false;
      }

      const payload = {
        customer: {
          name: formData.name,
          email: formData.email,
          address: formData.address,
        },
        items: items.map((item) => ({
          productId: item.product.id,
          quantity: item.quantity,
        })),
        notes: buildNotes(formData),
      };

      const order = await apiClient.createOrder(payload);
      setStatus({
        type: 'success',
        message: `Orden creada. Código: ${order.id.slice(0, 8).toUpperCase()}`,
      });
      clearCart();
      return true;
    } catch (error) {
      setStatus({ type: 'error', message: error.message });
      return false;
    } finally {
      setIsSubmitting(false);
    }
  };

  function buildNotes(formData) {
    const parts = [];
    if (formData?.notes) parts.push(formData.notes);
    const method = formData?.paymentMethod || 'card';
    let summary = `Pago simulado: ${
      method === 'card' ? 'Tarjeta' : method === 'transfer' ? 'Transferencia' : 'Contra entrega'
    }`;
    if (method === 'card' && formData?.cardNumber) {
      const last4 = String(formData.cardNumber).replace(/\D/g, '').slice(-4);
      if (last4) summary += ` • **** ${last4}`;
    }
    parts.push(summary);
    return parts.join(' | ');
  }

  return (
    <div className="container" style={{ padding: '1.5rem 0' }}>
      <a className="ghost" href="#/" style={{ marginBottom: '1rem', display: 'inline-block' }}>
        ← Seguir comprando
      </a>
      <h2>Checkout</h2>
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem' }}>
        <section>
          <h3>Datos del cliente y pago</h3>
          <CheckoutForm disabled={items.length === 0 || isSubmitting} onSubmit={handleCheckout} isSubmitting={isSubmitting} />
        </section>
        <aside>
          <h3>Resumen</h3>
          {items.length === 0 ? (
            <p className="cart-empty">No hay productos en el carrito.</p>
          ) : (
            <>
              <ul className="cart-items" style={{ marginBottom: '1rem' }}>
                {items.map((item) => (
                  <li key={item.product.id} className="cart-item">
                    <div className="cart-item__info">
                      <h4>{item.product.name}</h4>
                      <p>
                        ${item.product.price.toFixed(2)} × {item.quantity}
                      </p>
                    </div>
                  </li>
                ))}
              </ul>
              <div className="cart-summary">
                <span>Total</span>
                <strong>${cartTotal.toFixed(2)}</strong>
              </div>
            </>
          )}
          {status && (
            <p className={`cart-status cart-status--${status.type}`} style={{ marginTop: '1rem' }}>
              {status.message}
            </p>
          )}
        </aside>
      </div>
    </div>
  );
}

export default CheckoutPage;

