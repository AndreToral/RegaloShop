function FiltersBar({ filters, categories, onChange, onReset, error }) {
  const handlePriceChange = (event) => {
    const { name, value } = event.target;
    const numericValue = Number(value);
    if (Number.isNaN(numericValue)) return;
    if (name === 'minPrice') {
      onChange({ priceRange: [numericValue, filters.priceRange[1]] });
    } else {
      onChange({ priceRange: [filters.priceRange[0], numericValue] });
    }
  };

  return (
    <div className="filters-bar">
      <div className="filters-row">
        <div className="filter">
          <label htmlFor="search">Buscar</label>
          <input
            id="search"
            type="search"
            placeholder="Regalos, ropa, palabras clave..."
            value={filters.search}
            onChange={(event) => onChange({ search: event.target.value })}
          />
        </div>
        <div className="filter">
          <label htmlFor="category">Categoria</label>
          <select
            id="category"
            value={filters.category}
            onChange={(event) => onChange({ category: event.target.value })}
          >
            <option value="">Todas</option>
            {categories.map((category) => (
              <option key={category} value={category}>
                {category}
              </option>
            ))}
          </select>
          {error && <small className="filter-error">{error}</small>}
        </div>
        <div className="filter price-filter">
          <label>Precio</label>
          <div className="price-inputs">
            <input
              type="number"
              name="minPrice"
              min="0"
              step="5"
              value={filters.priceRange[0]}
              onChange={handlePriceChange}
            />
            <span className="price-separator">-</span>
            <input
              type="number"
              name="maxPrice"
              min="0"
              step="5"
              value={filters.priceRange[1]}
              onChange={handlePriceChange}
            />
          </div>
        </div>
        <div className="filter">
          <label htmlFor="sort">Ordenar</label>
          <select
            id="sort"
            value={filters.sort}
            onChange={(event) => onChange({ sort: event.target.value })}
          >
            <option value="price-asc">Precio: menor a mayor</option>
            <option value="price-desc">Precio: mayor a menor</option>
            <option value="stock-desc">Disponibilidad</option>
          </select>
        </div>
        <div className="filter actions">
          <button className="ghost" onClick={onReset}>
            Limpiar filtros
          </button>
        </div>
      </div>
    </div>
  );
}

export default FiltersBar;

