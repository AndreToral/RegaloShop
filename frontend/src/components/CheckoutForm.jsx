import { useEffect, useState } from 'react';

const INITIAL_STATE = {
  name: '',
  email: '',
  address: '',
  notes: '',
  paymentMethod: 'card', // 'card' | 'transfer' | 'cod'
  cardName: '',
  cardNumber: '',
  cardExpiry: '',
  cardCvv: '',
};

function CheckoutForm({ disabled, onSubmit, isSubmitting }) {
  const [formData, setFormData] = useState(INITIAL_STATE);

  useEffect(() => {
    if (disabled) {
      setFormData(INITIAL_STATE);
    }
  }, [disabled]);

  const handleChange = (event) => {
    const { name, value } = event.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (disabled) return;
    const result = await onSubmit(formData);
    if (result !== false) {
      setFormData(INITIAL_STATE);
    }
  };

  return (
    <form className="checkout-form" onSubmit={handleSubmit}>
      <h3>Finalizar compra</h3>
      <div className="form-group">
        <label htmlFor="name">Nombre completo</label>
        <input
          id="name"
          name="name"
          type="text"
          required
          value={formData.name}
          onChange={handleChange}
        />
      </div>
      <div className="form-group">
        <label htmlFor="email">Correo electronico</label>
        <input
          id="email"
          name="email"
          type="email"
          required
          value={formData.email}
          onChange={handleChange}
        />
      </div>
      <div className="form-group">
        <label htmlFor="address">Direccion de entrega</label>
        <textarea
          id="address"
          name="address"
          required
          rows="3"
          value={formData.address}
          onChange={handleChange}
        />
      </div>
      <div className="form-group">
        <label htmlFor="paymentMethod">Metodo de pago (simulado)</label>
        <select
          id="paymentMethod"
          name="paymentMethod"
          value={formData.paymentMethod}
          onChange={handleChange}
        >
          <option value="card">Tarjeta (simulado)</option>
          <option value="transfer">Transferencia (simulado)</option>
          <option value="cod">Pago contra entrega (simulado)</option>
        </select>
      </div>
      {formData.paymentMethod === 'card' && (
        <div className="form-group">
          <label>Detalles de tarjeta (no se envia al servidor)</label>
          <input
            placeholder="Nombre en la tarjeta"
            name="cardName"
            value={formData.cardName}
            onChange={handleChange}
          />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem', marginTop: '0.5rem' }}>
            <input
              placeholder="Numero de tarjeta"
              name="cardNumber"
              inputMode="numeric"
              value={formData.cardNumber}
              onChange={handleChange}
            />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem' }}>
              <input
                placeholder="MM/AA"
                name="cardExpiry"
                value={formData.cardExpiry}
                onChange={handleChange}
              />
              <input
                placeholder="CVV"
                name="cardCvv"
                inputMode="numeric"
                value={formData.cardCvv}
                onChange={handleChange}
              />
            </div>
          </div>
          <small style={{ color: '#6b7280' }}>
            Solo demostrativo: estos datos NO se almacenan ni se envian.
          </small>
        </div>
      )}
      <div className="form-group">
        <label htmlFor="notes">Notas para el envio (opcional)</label>
        <textarea
          id="notes"
          name="notes"
          rows="2"
          value={formData.notes}
          onChange={handleChange}
        />
      </div>
      <button className="primary" type="submit" disabled={disabled || isSubmitting}>
        {isSubmitting ? 'Procesando...' : 'Confirmar pedido'}
      </button>
    </form>
  );
}

export default CheckoutForm;
