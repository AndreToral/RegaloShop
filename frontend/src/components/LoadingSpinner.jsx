function LoadingSpinner({ message = 'Cargando' }) {
  return (
    <div className="loading">
      <div className="loading__spinner" aria-hidden="true" />
      <span>{message}</span>
    </div>
  );
}

export default LoadingSpinner;
