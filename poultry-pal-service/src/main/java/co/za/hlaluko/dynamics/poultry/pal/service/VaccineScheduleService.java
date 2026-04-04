package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Vaccine;
import co.za.hlaluko.dynamics.poultry.pal.utils.PoultryPalUtil;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class VaccineScheduleService {
  public List<Vaccine> generateBroilerVaccineSchedule(Date hatchDate, GrowingPhase growingPhase) {
    List<Vaccine> vaccines = new ArrayList<>();

    switch (growingPhase) {
      case BROODING_PHASE:
        // Vaccines for Brooding Phase (Day 1 to Day 7)
        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Bronchitis and Newcastle Disease Vaccine",
                "Day 1",
                "Prevent Infectious Bronchitis disease",
                "Coarse spray",
                "Administer at the hatchery or upon receipt. Vaccine: NOBILIS® ND C2",
                hatchDate,
                null,
                false,
                null,
                null,
                null));
        break;

      case GROWING_REARING_PHASE:
        // Vaccines for Growing or Rearing Phase (Day 8 to Day 21)
        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease and Infectious Bronchitis Vaccine",
                "Day 10",
                "Prevent respiratory diseases",
                "Drinking water",
                "Ensure clean water before administration. Vaccine: NOBILIS® IB MA5 and CLONE 30",
                PoultryPalUtil.addDays(hatchDate, 10),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Bursal Disease (Gumboro) Vaccine",
                "Day 14",
                "Prevent Gumboro disease",
                "Drinking water",
                "Ensure the vaccine is administered based on the flock's health. Vaccine: NOBILIS® GUMBORO D78",
                PoultryPalUtil.addDays(hatchDate, 14),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Bursal Disease (Gumboro) Vaccine",
                "Day 19",
                "Prevent Gumboro disease",
                "Drinking water",
                "Ensure the vaccine is administered based on the flock's health. Vaccine: NOBILIS® GUMBORO D78",
                PoultryPalUtil.addDays(hatchDate, 19),
                null,
                false,
                null,
                null,
                null));

        break;

      case PRODUCTION_FINISHING_PHASE:
        // Vaccines for Production or Finishing Phase (Day 22 and onward)
        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease Booster",
                "Day 21",
                "Enhance immunity against Newcastle disease",
                "Drinking water",
                "Administer booster after initial vaccination. Vaccine: NOBILIS® ND CLONE 30",
                PoultryPalUtil.addDays(hatchDate, 21),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease Booster",
                "Day 28",
                "Enhance immunity against Newcastle disease",
                "Drinking water",
                "Administer booster after initial vaccination.",
                PoultryPalUtil.addDays(hatchDate, 28),
                null,
                false,
                null,
                null,
                null));

        break;

      default:
        throw new IllegalArgumentException("Invalid growing phase: " + growingPhase);
    }

    return vaccines;
  }

  public List<Vaccine> generateLayerVaccineSchedule(Date hatchDate, GrowingPhase growingPhase) {
    List<Vaccine> vaccines = new ArrayList<>();

    switch (growingPhase) {
      case BROODING_PHASE:
        // Vaccines for Brooding Phase (Day 1 to Day 7)
        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Marek's Disease Vaccine",
                "Day 1",
                "Prevent Marek's disease",
                "Subcutaneous injection",
                "Usually administered at the hatchery.",
                hatchDate,
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease (NCD) Vaccine",
                "Day 5-7",
                "Prevent and control respiratory and systemic diseases",
                "Eye drop / course spray",
                "Prepare the vaccine as instructed and administer it directly to the eyes or via spray for effective absorption.",
                PoultryPalUtil.addDays(hatchDate, 5),
                null,
                false,
                null,
                null,
                null));
        break;

      case GROWING_REARING_PHASE:
        // Vaccines for Growing or Rearing Phase (Day 8 to Day 21)
        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Bursal Disease (IBD or Gumboro) Vaccine",
                "Day 14",
                "Prevent Gumboro disease",
                "Drinking water",
                "Administer based on flock health.",
                PoultryPalUtil.addDays(hatchDate, 14),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease Vaccine",
                "Day 18",
                "Prevent and control respiratory and systemic diseases",
                "Fine spray (Atomist, Turb-air)",
                "Ensure equipment is clean and calibrated, follow vaccine preparation guidelines, and administer in a controlled environment to minimize stress.",
                PoultryPalUtil.addDays(hatchDate, 18),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Bursal Disease Vaccine",
                "Day 20",
                "Prevent Gumboro disease",
                "Drinking water",
                "Administer based on flock health.",
                PoultryPalUtil.addDays(hatchDate, 20),
                null,
                false,
                null,
                null,
                null));
        break;

      case PRODUCTION_FINISHING_PHASE:
        // Vaccines for Production or Finishing Phase (Day 22 and onward)
        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease and Infectious Bronchitis Vaccine",
                "6 Weeks",
                "Prevent and control respiratory and systemic diseases",
                "Fine spray",
                "Administer the vaccine in a controlled environment to minimize stress on the birds and ensure uniform distribution.",
                PoultryPalUtil.addDays(hatchDate, 42),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease Vaccine",
                "10 Weeks",
                "Prevent and control respiratory and systemic diseases",
                "Fine spray",
                "Administer the vaccine in a controlled environment to minimize stress on the birds and ensure uniform distribution.",
                PoultryPalUtil.addDays(hatchDate, 70),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Coryza Vaccine",
                "12 Weeks",
                "Ensure better overall flock health, reduce disease outbreaks, and improve the sustainability of poultry farming operations.",
                "Subcutaneous injection",
                "Ensure the vaccine is prepared as per the manufacturer's guidelines, including proper dilution or mixing with the diluent (if required).",
                PoultryPalUtil.addDays(hatchDate, 84),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Fowl Pox Vaccine",
                "12 Weeks",
                "Prevent fowl pox",
                "Wing web stab",
                "Administer if fowl pox is prevalent in the area.",
                PoultryPalUtil.addDays(hatchDate, 84),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Laryngotracheitis Vaccine",
                "12 Weeks",
                "Protect poultry from Infectious Laryngotracheitis (ILT)",
                "Eyedrop",
                "Ensure the vaccine is prepared according to the manufacturer's instructions. This includes proper dilution and handling to maintain efficacy.",
                PoultryPalUtil.addDays(hatchDate, 84),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Avian Encephalomyelitis (AE) Vaccine",
                "13 Weeks",
                "Prevent and control Avian Encephalomyelitis, a viral disease that primarily affects young chickens.",
                "Drinking water",
                "Ensure that the vaccine is administered according to the manufacturer's guidelines, using the correct dosage and method.",
                PoultryPalUtil.addDays(hatchDate, 91),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease Vaccine",
                "14 Weeks",
                "Ensure effective and efficient delivery of the vaccine to a large number of birds, particularly in large flocks.",
                "Fine spray",
                "Ensure that the fine spray equipment (e.g., Atomist or Turb-air sprayer) is clean, calibrated, and in good working condition before use.",
                PoultryPalUtil.addDays(hatchDate, 98),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease (NCD) Vaccine",
                "16 Weeks",
                "Prevent and control respiratory diseases caused by Newcastle Disease.",
                "Intramuscular injection",
                "Ensure the vaccine is administered using a sterile needle and syringe. Properly handle the bird to avoid injury during injection. Administer in the recommended dose to ensure effective immunity.",
                PoultryPalUtil.addDays(hatchDate, 112),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Bronchitis (IB) Vaccine",
                "16 Weeks",
                "Prevent respiratory diseases caused by Infectious Bronchitis virus.",
                "Intramuscular injection",
                "Administer the vaccine using a clean, sterile needle and syringe. Ensure that the vaccination site is properly disinfected to avoid infections. Monitor for any adverse reactions post-vaccination.",
                PoultryPalUtil.addDays(hatchDate, 112),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Egg Drop Syndrome (EDS) Vaccine",
                "16 Weeks",
                "Prevent Egg Drop Syndrome, which affects egg production in poultry.",
                "Intramuscular injection",
                "Administer the vaccine at the recommended dosage using sterile equipment. Ensure proper injection technique to avoid tissue damage. Observe birds post-vaccination for any reactions.",
                PoultryPalUtil.addDays(hatchDate, 112),
                null,
                false,
                null,
                null,
                null));

        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Infectious Coryza Vaccine",
                "16 Weeks",
                "Prevent and control Infectious Coryza, a bacterial respiratory infection in poultry.",
                "Intramuscular injection",
                "Inject the vaccine at the prescribed site using sterile equipment. Handle birds carefully during vaccination to minimize stress. Check for any immediate post-vaccination reactions.",
                PoultryPalUtil.addDays(hatchDate, 112),
                null,
                false,
                null,
                null,
                null));

        // layer chickens are kept for 72-80 weeks (approximately 18-20 months) before they are
        // culled or replaced
        int layerLifespanInDays = 80 * 7;
        vaccines.add(
            new Vaccine(
                UUID.randomUUID().toString(),
                "Newcastle Disease Vaccine",
                "As needed",
                "Ensure effective and efficient delivery of the vaccine to a large number of birds, particularly in large flocks.",
                "Fine spray",
                "Fine spray every 4-6 weeks during laying period",
                PoultryPalUtil.addDays(hatchDate, layerLifespanInDays),
                null,
                false,
                null,
                null,
                null));

        break;

      default:
        throw new IllegalArgumentException("Invalid growing phase: " + growingPhase);
    }

    return vaccines;
  }

  public List<Vaccine> generateLayerVaccineSchedule(Date hatchDate) {
    List<Vaccine> vaccines = new ArrayList<>();

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Marek's Disease Vaccine",
            "Day 1",
            "Prevent Marek's disease",
            "Subcutaneous injection",
            "Usually administered at the hatchery.",
            hatchDate,
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Newcastle Disease (NCD) Vaccine",
            "Day 5-7",
            "Prevent and control respiratory and systemic diseases",
            "Eye drop / course spray",
            "Prepare the vaccine as instructed and administer it directly to the eyes or via spray for effective absorption.",
            PoultryPalUtil.addDays(hatchDate, 5),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Infectious Bursal Disease (IBD or Gumboro) Vaccine",
            "Day 14",
            "Prevent Gumboro disease",
            "Drinking water",
            "Administer based on flock health.",
            PoultryPalUtil.addDays(hatchDate, 14),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Newcastle Disease Vaccine",
            "Day 18",
            "Prevent and control respiratory and systemic diseases",
            "Fine spray (Atomist, Turb-air)",
            "Ensure equipment is clean and calibrated, follow vaccine preparation guidelines,"
                + " and administer in a controlled environment to minimize stress.",
            PoultryPalUtil.addDays(hatchDate, 18),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Infectious Bursal Disease Vaccine",
            "Day 20",
            "Prevent Gumboro disease",
            "Drinking water",
            "Administer based on flock health.",
            PoultryPalUtil.addDays(hatchDate, 20),
            null,
            false,
            null,
            null,
            null));
    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Newcastle Disease and Infectious Bronchitis Vaccine",
            "6 Weeks",
            "Prevent and control respiratory and systemic diseases",
            "Fine spray",
            "Administer the vaccine in a controlled environment to minimize stress on the birds and ensure uniform distribution.",
            PoultryPalUtil.addDays(hatchDate, 42),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Newcastle Disease Vaccine",
            "10 Weeks",
            "Prevent and control respiratory and systemic diseases",
            "Fine spray",
            "Administer the vaccine in a controlled environment to minimize stress on the birds and ensure uniform distribution.",
            PoultryPalUtil.addDays(hatchDate, 70),
            null,
            false,
            null,
            null,
            null));
    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Infectious Coryza Vaccine",
            "12 Weeks",
            "Ensure better overall flock health, reduce disease outbreaks, and improve the sustainability of poultry farming operations.",
            "Subcutaneous injection",
            "Ensure the vaccine is prepared as per the manufacturer's guidelines, including proper dilution or mixing with the diluent (if required).",
            PoultryPalUtil.addDays(hatchDate, 84),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Fowl Pox Vaccine",
            "12 Weeks",
            "Prevent fowl pox",
            "Wing web stab",
            "Administer if fowl pox is prevalent in the area.",
            PoultryPalUtil.addDays(hatchDate, 84),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Infectious Laryngotracheitis Vaccine",
            "12 Weeks",
            "Protect poultry from Infectious Laryngotracheitis (ILT)",
            "Eyedrop",
            "Ensure the vaccine is prepared according to the manufacturer's instructions. This includes proper dilution and handling to maintain efficacy.",
            PoultryPalUtil.addDays(hatchDate, 84),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Avian Encephalomyelitis (AE) Vaccine",
            "13 Weeks",
            "Prevent and control Avian Encephalomyelitis, a viral disease that primarily affects young chickens. ",
            "Drinking water",
            "Ensure that the vaccine is administered according to the manufacturer's guidelines, using the correct dosage and method.",
            PoultryPalUtil.addDays(hatchDate, 91),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Newcastle Disease Vaccine",
            "14 Weeks",
            "Ensure effective and efficient delivery of the vaccine to a large number of birds, particularly in large flocks.",
            "Fine spray",
            "Ensure that the fine spray equipment (e.g., Atomist or Turb-air sprayer) is clean, calibrated, and in good working condition before use.",
            PoultryPalUtil.addDays(hatchDate, 98),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Newcastle Disease (NCD) Vaccine",
            "16 Weeks",
            "Prevent and control respiratory diseases caused by Newcastle Disease.",
            "Intramuscular injection",
            "Ensure the vaccine is administered using a sterile needle and syringe. Properly handle the bird to avoid injury during injection. Administer in the recommended dose to ensure effective immunity.",
            PoultryPalUtil.addDays(hatchDate, 112),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Infectious Bronchitis (IB) Vaccine",
            "16 Weeks",
            "Prevent respiratory diseases caused by Infectious Bronchitis virus.",
            "Intramuscular injection",
            "Administer the vaccine using a clean, sterile needle and syringe. Ensure that the vaccination site is properly disinfected to avoid infections. Monitor for any adverse reactions post-vaccination.",
            PoultryPalUtil.addDays(hatchDate, 112),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Egg Drop Syndrome (EDS) Vaccine",
            "16 Weeks",
            "Prevent Egg Drop Syndrome, which affects egg production in poultry.",
            "Intramuscular injection",
            "Administer the vaccine at the recommended dosage using sterile equipment. Ensure proper injection technique to avoid tissue damage. Observe birds post-vaccination for any reactions.",
            PoultryPalUtil.addDays(hatchDate, 112),
            null,
            false,
            null,
            null,
            null));

    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Infectious Coryza Vaccine",
            "16 Weeks",
            "Prevent and control Infectious Coryza, a bacterial respiratory infection in poultry.",
            "Intramuscular injection",
            "Inject the vaccine at the prescribed site using sterile equipment. Handle birds carefully during vaccination to minimize stress. Check for any immediate post-vaccination reactions.",
            PoultryPalUtil.addDays(hatchDate, 112),
            null,
            false,
            null,
            null,
            null));

    // layer chickens are kept for 72-80 weeks
    // (approximately 18-20 months) before they are culled or replaced.
    int layerLifespanInDays = 80 * 7;
    vaccines.add(
        new Vaccine(
            UUID.randomUUID().toString(),
            "Newcastle Disease Vaccine",
            "As needed",
            "Ensure effective and efficient delivery of the vaccine to a large number of birds, particularly in large flocks.",
            "Fine spray",
            "Fine spray every 4-6 weeks during laying period",
            PoultryPalUtil.addDays(hatchDate, layerLifespanInDays),
            null,
            false,
            null,
            null,
            null));

    return vaccines;
  }
}
