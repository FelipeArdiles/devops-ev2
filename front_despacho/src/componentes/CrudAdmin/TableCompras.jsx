import { useState, useEffect, useCallback } from "react";
import { Modal } from "./Modal";
import { FormDespacho } from "./FormDespacho";
import axios from "axios";
import { API_VENTAS, jsonHeaders } from "../../config/api";

export const TableCompras = () => {
  const [ventas, setVentas] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const compras = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(API_VENTAS, { headers: jsonHeaders });
      setVentas(response.data);
    } catch (err) {
      console.error("Error al cargar ventas:", err);
      setError("No se pudieron cargar las órdenes de compra. Revisa que los backends estén activos.");
      setVentas([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    compras();
  }, [compras]);

  const [openModal, setOpenModal] = useState(false);
  const [ventaSeleccionada, setVentaSeleccionada] = useState(null);

  const handleAbrirModal = (venta) => {
    setVentaSeleccionada(venta);
    setOpenModal(true);
  };

  const ventasPendientes = ventas.filter((venta) => !venta.despachoGenerado);

  return (
    <>
      <section className="grid text-center grid-cols-12 mb-8">
        <div className="col-span-12 flex justify-center">
          <div className="col-span-10 p-2 bg-white border border-gray-200 rounded-lg shadow w-full max-w-5xl overflow-x-auto">
            {loading && (
              <p className="py-8 text-gray-500">Cargando órdenes de compra...</p>
            )}
            {error && (
              <p className="py-8 text-red-600">{error}</p>
            )}
            {!loading && !error && ventasPendientes.length === 0 && (
              <p className="py-8 text-gray-500">
                No hay órdenes pendientes de despacho.
              </p>
            )}
            {!loading && !error && ventasPendientes.length > 0 && (
              <table className="table-auto w-full">
                <thead>
                  <tr className="py-10">
                    <th className="pr-10">Orden de compra</th>
                    <th className="pr-10">direccion</th>
                    <th className="pr-10">fecha de compra</th>
                    <th className="pr-10">valor total</th>
                    <th className="pr-10"></th>
                  </tr>
                </thead>
                <tbody>
                  {ventasPendientes.map((venta) => (
                    <tr key={venta.idVenta}>
                      <td className="pr-10 py-4">{venta.idVenta}</td>
                      <td className="pr-10 py-4">{venta.direccionCompra}</td>
                      <td className="pr-10 py-4">{venta.fechaCompra}</td>
                      <td className="pr-10 py-4">${venta.valorCompra}</td>
                      <td>
                        <button
                          onClick={() => handleAbrirModal(venta)}
                          className="py-1 bg-orange-200 px-8 rounded-xl shadow-md hover:bg-orange-300/70 transition-all duration-300"
                        >
                          Generar Despacho
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </section>
      <Modal
        onClose={() => setOpenModal(false)}
        open={openModal}
      >
        {ventaSeleccionada && (
          <FormDespacho
            venta={ventaSeleccionada}
            onClose={() => {
              setOpenModal(false);
              compras();
            }}
          />
        )}
      </Modal>
    </>
  );
};
