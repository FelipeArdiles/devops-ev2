const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

export const VENTAS_API = `${API_BASE}/api/v1/ventas`;
export const DESPACHOS_API = `${API_BASE}/api/v1/despachos`;

export const defaultHeaders = {
  "Content-Type": "application/json",
  Accept: "application/json",
};
