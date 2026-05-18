import { useForm } from "react-hook-form";
import Swal from "sweetalert2";
import axios from "axios";
import { API_VENTAS, API_DESPACHOS, jsonHeaders } from "../../config/api";

export const FormDespacho = ({ venta, onClose }) => {
  const { register, handleSubmit } = useForm();

  const onSubmit = async (data) => {
    const jsonData = {
      fechaDespacho: data.fechaDespacho,
      patenteCamion: data.patenteCamion,
      intento: 0,
      despachado: false,
      idCompra: venta.idVenta,
      direccionCompra: venta.direccionCompra,
      valorCompra: venta.valorCompra,
    };

    try {
      await axios.put(
        `${API_VENTAS}/${venta.idVenta}`,
        { despachoGenerado: true },
        { headers: jsonHeaders }
      );
      await axios.post(API_DESPACHOS, jsonData, { headers: jsonHeaders });
      Swal.fire({
        title: "Despacho registrado 🛻!",
        text: "El despacho ha sido generado con éxito en la base de datos",
        icon: "success",
        confirmButtonText: "Aceptar",
      });
      onClose();
    } catch (error) {
      console.error("Error en la solicitud:", error);
      Swal.fire({
        title: "Error",
        text: "No se pudo registrar el despacho.",
        icon: "error",
      });
    }
  };

  return (
    <form
      onSubmit={handleSubmit(onSubmit)}
      className="flex flex-col justify-center text-center px-24 text-xl"
    >
      <div className="mx-auto text-3xl font-bold mb-10 text-teal-600">
        Ingreso de orden de despacho
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Fecha de despacho</label>
        <input
          type="date"
          className="border border-gray-300 rounded-lg block w-full p-1"
          {...register("fechaDespacho", { required: true })}
        />
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Patente de camión</label>
        <input
          type="text"
          placeholder="Ej: AABB12"
          className="border border-gray-300 rounded-lg block w-full p-1"
          {...register("patenteCamion", { required: true })}
        />
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Orden de compra asociado</label>
        <input
          type="number"
          disabled
          value={venta.idVenta}
          readOnly
          className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1"
        />
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Dirección de entrega</label>
        <input
          type="text"
          disabled
          value={venta.direccionCompra}
          readOnly
          className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1"
        />
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Valor de compra</label>
        <input
          type="number"
          value={venta.valorCompra}
          readOnly
          disabled
          className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1"
        />
      </div>
      <button
        className="py-6 px-14 rounded-lg bg-teal-600 text-white font-bold mb-14"
        type="submit"
      >
        Asignar despacho
      </button>
    </form>
  );
};
