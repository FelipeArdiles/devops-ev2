package com.citt.config;

import com.citt.persistence.entity.Venta;
import com.citt.persistence.repository.VentaRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

@Component
public class DatosInicialesVentas implements CommandLineRunner {

    private final VentaRepository ventaRepository;

    public DatosInicialesVentas(VentaRepository ventaRepository) {
        this.ventaRepository = ventaRepository;
    }

    @Override
    public void run(String... args) {
        if (ventaRepository.count() > 0) {
            return;
        }
        ventaRepository.save(Venta.builder()
                .direccionCompra("P Sherman Calle Wallabi 42 Sydney")
                .valorCompra(22990)
                .fechaCompra(LocalDate.of(2024, 2, 2))
                .despachoGenerado(false)
                .build());
        ventaRepository.save(Venta.builder()
                .direccionCompra("Avenida Siempre Viva 742")
                .valorCompra(12590)
                .fechaCompra(LocalDate.of(2024, 3, 5))
                .despachoGenerado(false)
                .build());
        ventaRepository.save(Venta.builder()
                .direccionCompra("Av. Providencia 1234, Santiago")
                .valorCompra(13990)
                .fechaCompra(LocalDate.of(2024, 4, 20))
                .despachoGenerado(false)
                .build());
        ventaRepository.save(Venta.builder()
                .direccionCompra("Calle Presidente Kirby 8528")
                .valorCompra(9990)
                .fechaCompra(LocalDate.of(2024, 4, 15))
                .despachoGenerado(true)
                .build());
    }
}
