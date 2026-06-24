package com.citt.config;

import com.citt.persistence.entity.Despacho;
import com.citt.persistence.repository.DespachoRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

@Component
public class DatosInicialesDespachos implements CommandLineRunner {

    private final DespachoRepository despachoRepository;

    public DatosInicialesDespachos(DespachoRepository despachoRepository) {
        this.despachoRepository = despachoRepository;
    }

    @Override
    public void run(String... args) {
        if (despachoRepository.count() > 0) {
            return;
        }
        Despacho demo = new Despacho();
        demo.setFechaDespacho(LocalDate.of(2024, 5, 10));
        demo.setPatenteCamion("AABB12");
        demo.setIntento(1);
        demo.setIdCompra(4L);
        demo.setDireccionCompra("Calle Presidente Kirby 8528");
        demo.setValorCompra(9990L);
        demo.setDespachado(false);
        despachoRepository.save(demo);
    }
}
