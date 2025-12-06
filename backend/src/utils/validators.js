/**
 * Funciones de validación para el backend de Regaloshop
 * 
 * PRINCIPIO DE RESPONSABILIDAD ÚNICA:
 * Cada función hace UNA SOLA cosa
 * Las funciones de cálculo SOLO calculan
 * Las funciones de validación SOLO validan
 */


// FUNCIONES DE VALIDACIÓN (solo validan, retornan true/false)


/**
 * Valida que un valor sea un numero valido
 * @param {any} valor - El valor a validar
 * @returns {boolean} - true si es un numero valido
 */
function esNumeroValido(valor) {
  return typeof valor === 'number' && !isNaN(valor);
}

/**
 * Valida que un numero sea mayor a cero
 * @param {number} valor - El valor a validar
 * @returns {boolean} - true si el numero es mayor a cero
 */
function esNumeroPositivo(valor) {
  return valor > 0;
}

/**
 * Valida que un email tenga formato correcto
 * @param {string} email - El email a validar
 * @returns {boolean} - true si es valido, false si no
 */
function esEmailValido(email) {
  const regexEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regexEmail.test(email);
}


// FUNCIONES DE CÁLCULO (solo calculan, asumen datos ya validados)


/**
 * Redondea un numero a dos decimales
 * @param {number} valor - El valor a redondear
 * @returns {number} - El valor redondeado a 2 decimales
 */
function redondearADosDecimales(valor) {
  return Number(Number(valor).toFixed(2));
}

/**
 * Determina el costo de envio segun el umbral
 * @param {number} subtotal - El subtotal de la orden
 * @param {number} umbralEnvioGratis - El umbral para envio gratis (default 80)
 * @param {number} costoEnvioEstandar - El costo de envio estandar (default 6.99)
 * @returns {number} - El costo de envio
 */
function determinarCostoEnvio(subtotal, umbralEnvioGratis = 80, costoEnvioEstandar = 6.99) {
  return subtotal >= umbralEnvioGratis ? 0 : costoEnvioEstandar;
}

/**
 * Compara si el stock es suficiente para la cantidad solicitada
 * @param {number} stockDisponible - Stock disponible
 * @param {number} cantidadSolicitada - Cantidad solicitada
 * @returns {boolean} - true si hay stock suficiente
 */
function compararStockConCantidad(stockDisponible, cantidadSolicitada) {
  return stockDisponible >= cantidadSolicitada;
}

module.exports = {
  esNumeroValido,
  esNumeroPositivo,
  esEmailValido,
  redondearADosDecimales,
  determinarCostoEnvio,
  compararStockConCantidad,
};
