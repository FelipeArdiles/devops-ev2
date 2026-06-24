function Reviews() {
  const partners = [
    { name: "Logística Norte", color: "bg-sky-600" },
    { name: "Express Sur", color: "bg-emerald-600" },
    { name: "Cargo Prime", color: "bg-violet-600" },
  ];

  return (
    <div className="bg-white sm:py-10">
      <div className="mx-auto text-center">
        <h2 className="text-center text-lg font-semibold leading-8 text-gray-900">
          Empresas que confían en nosotros
        </h2>
        <div className="mx-auto mt-10 grid max-w-lg grid-cols-3 items-center gap-8 sm:max-w-xl lg:mx-0 lg:max-w-none">
          {partners.map((partner) => (
            <div
              key={partner.name}
              className={`${partner.color} mx-auto flex h-16 w-full max-w-[158px] items-center justify-center rounded-lg px-3 text-sm font-semibold text-white shadow`}
            >
              {partner.name}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default Reviews;
