/**
 * Pruebas unitarias para las funciones de validación de Regaloshop
 * 
 * FORMATO AAA (Arrange-Act-Assert) CON NOMBRES DESCRIPTIVOS
 * Cada función hace UNA SOLA cosa (Principio de Responsabilidad Única)
 * Cada test prueba UN SOLO escenario
 * 
 * @author Estudiante
 */

const {
  esNumeroValido,
  esNumeroPositivo,
  esEmailValido,
  redondearADosDecimales,
  determinarCostoEnvio,
  compararStockConCantidad,
} = require('../src/utils/validators');


// TEST 1: esNumeroValido - Caso feliz con numero valido

describe('esNumeroValido', () => {
  test('retorna verdadero cuando el valor es un numero valido', () => {
    // Arrange
    const numeroDecimalValido = 10.5;

    // Act
    const resultadoObtenido = esNumeroValido(numeroDecimalValido);

    // Assert
    expect(resultadoObtenido).toBe(true);
  });

  // TEST 2: esNumeroValido - Caso de error con string
  test('retorna falso cuando el valor es una cadena de texto', () => {
    // Arrange
    const valorCadenaDeTexto = 'diez';

    // Act
    const resultadoObtenido = esNumeroValido(valorCadenaDeTexto);

    // Assert
    expect(resultadoObtenido).toBe(false);
  });
});


// TEST 3: esNumeroPositivo - Caso feliz con numero positivo

describe('esNumeroPositivo', () => {
  test('retorna verdadero cuando el numero es mayor a cero', () => {
    // Arrange
    const numeroMayorACero = 5;

    // Act
    const resultadoObtenido = esNumeroPositivo(numeroMayorACero);

    // Assert
    expect(resultadoObtenido).toBe(true);
  });

  // TEST 4: esNumeroPositivo - Caso de error con cero
  test('retorna falso cuando el numero es cero', () => {
    // Arrange
    const numeroCero = 0;

    // Act
    const resultadoObtenido = esNumeroPositivo(numeroCero);

    // Assert
    expect(resultadoObtenido).toBe(false);
  });
});


// TEST 5: esEmailValido - Caso feliz con email correcto

describe('esEmailValido', () => {
  test('retorna verdadero cuando el email tiene formato correcto', () => {
    // Arrange
    const emailConFormatoCorrecto = 'usuario@dominio.com';

    // Act
    const resultadoObtenido = esEmailValido(emailConFormatoCorrecto);

    // Assert
    expect(resultadoObtenido).toBe(true);
  });

  // TEST 6: esEmailValido - Caso de error con email sin arroba
  test('retorna falso cuando el email no contiene arroba', () => {
    // Arrange
    const emailSinArroba = 'usuariodominio.com';

    // Act
    const resultadoObtenido = esEmailValido(emailSinArroba);

    // Assert
    expect(resultadoObtenido).toBe(false);
  });
});


// TEST 7: redondearADosDecimales - Caso feliz con numero largo

describe('redondearADosDecimales', () => {
  test('redondea un numero decimal largo a exactamente dos decimales', () => {
    // Arrange
    const numeroDecimalLargo = 10.12345;
    const resultadoEsperado = 10.12;

    // Act
    const resultadoObtenido = redondearADosDecimales(numeroDecimalLargo);

    // Assert
    expect(resultadoObtenido).toBe(resultadoEsperado);
  });
});


// TEST 8: determinarCostoEnvio - Caso feliz con envio gratis

describe('determinarCostoEnvio', () => {
  test('retorna cero cuando el subtotal es mayor o igual al umbral', () => {
    // Arrange
    const subtotalMayorAlUmbral = 100;
    const costoEnvioEsperado = 0;

    // Act
    const costoEnvioObtenido = determinarCostoEnvio(subtotalMayorAlUmbral);

    // Assert
    expect(costoEnvioObtenido).toBe(costoEnvioEsperado);
  });

  // TEST 9: determinarCostoEnvio - Caso con costo de envio
  test('retorna el costo estandar cuando el subtotal es menor al umbral', () => {
    // Arrange
    const subtotalMenorAlUmbral = 50;
    const costoEnvioEstandarEsperado = 6.99;

    // Act
    const costoEnvioObtenido = determinarCostoEnvio(subtotalMenorAlUmbral);

    // Assert
    expect(costoEnvioObtenido).toBe(costoEnvioEstandarEsperado);
  });
});


// TEST 10: compararStockConCantidad - Caso feliz con stock suficiente

describe('compararStockConCantidad', () => {
  test('retorna verdadero cuando el stock disponible es mayor a la cantidad solicitada', () => {
    // Arrange
    const stockDisponibleEnInventario = 10;
    const cantidadSolicitadaPorCliente = 5;

    // Act
    const hayStockSuficiente = compararStockConCantidad(stockDisponibleEnInventario, cantidadSolicitadaPorCliente);

    // Assert
    expect(hayStockSuficiente).toBe(true);
  });
});
