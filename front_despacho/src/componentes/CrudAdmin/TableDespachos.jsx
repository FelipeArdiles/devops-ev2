import { useState, useEffect, useCallback } from "react";
import axios from "axios";
import { Modal } from "./Modal";
import { FormCierreDespacho } from "./FormCierreDespacho";
import { API_DESPACHOS, jsonHeaders } from "../../config/api";

export const TableDespachos = () => {
  const [despachos, setDespachos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const cargarDespachos = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(API_DESPACHOS, { headers: jsonHeaders });
      setDespachos(response.data);
    } catch (err) {
      console.error("Error al cargar despachos:", err);
      setError("No se pudieron cargar los despachos. Revisa que los backends estén activos.");
      setDespachos([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    cargarDespachos();
  }, [cargarDespachos]);

  const [openModal, setOpenModal] = useState(false);
  const [despachoSeleccionado, setDespachoSeleccionado] = useState(null);

  const handleAbrirModal = (despacho) => {
    setDespachoSeleccionado(despacho);
    setOpenModal(true);
  };

  return (
    <>
      <section className="grid text-center grid-cols-12 mb-8">
        <div className="col-span-12 flex justify-center">
          <div className="col-span-10 p-2 bg-white border border-gray-200 rounded-lg shadow w-full max-w-6xl overflow-x-auto">
            {loading && (
              <p className="py-8 text-gray-500">Cargando órdenes de despacho...</p>
            )}
            {error && <p className="py-8 text-red-600">{error}</p>}
            {!loading && !error && despachos.length === 0 && (
              <p className="py-8 text-gray-500">No hay despachos registrados.</p>
            )}
            {!loading && !error && despachos.length > 0 && (
              <table className="table-auto w-full">
                <thead>
                  <tr className="py-10">
                    <th className="pr-6">Orden de despacho</th>
                    <th className="pr-6">Orden de compra</th>
                    <th className="pr-6">Dirección de entrega</th>
                    <th className="pr-6">Fecha despacho</th>
                    <th className="pr-6">Patente Camión</th>
                    <th className="pr-6">Entregado</th>
                    <th className="pr-6">Intentos de entrega</th>
                    <th className="pr-6"></th>
                  </tr>
                </thead>
                <tbody>
                  {despachos.map((despacho) => (
                    <tr key={despacho.idDespacho}>
                      <td className="pr-6 py-4">{despacho.idDespacho}</td>
                      <td className="pr-6 py-4">{despacho.idCompra}</td>
                      <td className="pr-6 py-4">{despacho.direccionCompra}</td>
                      <td className="pr-6 py-4">{despacho.fechaDespacho}</td>
                      <td className="pr-6 py-4">{despacho.patenteCamion}</td>
                      <td className="pr-6 py-4">
                        {despacho.despachado
                          ? "Despacho entregado"
                          : "Despacho pendiente"}
                      </td>
                      <td className="pr-6 py-4">{despacho.intento}</td>
                      <td>
                        <button
                          onClick={() => handleAbrirModal(despacho)}
                          className="py-1 bg-orange-200 px-6 rounded-xl shadow-md hover:bg-orange-300/70 transition-all duration-300"
                        >
                          Cerrar despacho
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
      <Modal onClose={() => setOpenModal(false)} open={openModal}>
        {despachoSeleccionado && (
          <FormCierreDespacho
            despacho={despachoSeleccionado}
            onClose={() => {
              setOpenModal(false);
              cargarDespachos();
            }}
          />
        )}
      </Modal>
    </>
  );
};
