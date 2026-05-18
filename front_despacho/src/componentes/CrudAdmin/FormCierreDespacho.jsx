import { useForm } from "react-hook-form";
import Swal from "sweetalert2";
import axios from "axios";
import { API_DESPACHOS, jsonHeaders } from "../../config/api";

export const FormCierreDespacho = ({ despacho, onClose }) => {
  const { register, handleSubmit } = useForm();

  const onSubmit = async (data) => {
    const jsonData = {
      ...despacho,
      intento: Number(data.intento),
      despachado: data.despachado === "true" || data.despachado === true,
    };

    try {
      await axios.put(
        `${API_DESPACHOS}/${despacho.idDespacho}`,
        jsonData,
        { headers: jsonHeaders }
      );
      Swal.fire({
        title: "Despacho modificado 🛻!",
        text: "El despacho ha sido modificado exitosamente",
        icon: "success",
        confirmButtonText: "Aceptar",
      });
      onClose();
    } catch (error) {
      console.error("Error en la solicitud:", error);
      Swal.fire({
        title: "Error",
        text: "No se pudo modificar el despacho.",
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
        Editar y cierre de despacho
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">ID despacho</label>
        <input
          disabled
          type="text"
          className="border border-gray-300 rounded-lg block w-full p-1 text-slate-400"
          value={despacho.idDespacho}
          readOnly
        />
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Fecha despacho</label>
        <input
          type="date"
          className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1"
          value={despacho.fechaDespacho}
          disabled
          readOnly
        />
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Patente Camión</label>
        <input
          type="text"
          disabled
          value={despacho.patenteCamion}
          readOnly
          className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1"
        />
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Intentos de entrega</label>
        <input
          type="number"
          defaultValue={despacho.intento}
          className="border border-gray-300 rounded-lg block w-full p-1"
          {...register("intento", { required: true })}
        />
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">Despacho entregado</label>
        <select
          defaultValue={String(despacho.despachado)}
          className="border border-gray-300 rounded-lg block w-full p-1"
          {...register("despachado", { required: true })}
        >
          <option value="false">Despacho abierto</option>
          <option value="true">Cerrar despacho</option>
        </select>
      </div>
      <div className="mb-5">
        <label className="block font-bold mb-2">ID Compra</label>
        <input
          type="text"
          className="border border-gray-300 rounded-lg block w-full text-slate-400 p-1"
          disabled
          readOnly
          value={despacho.idCompra}
        />
      </div>
      <button
        className="py-6 px-14 rounded-lg bg-teal-600 text-white font-bold mb-14"
        type="submit"
      >
        Modificar Despacho
      </button>
    </form>
  );
};
