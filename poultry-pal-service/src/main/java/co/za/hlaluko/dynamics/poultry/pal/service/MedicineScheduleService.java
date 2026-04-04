package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.Medicine;
import co.za.hlaluko.dynamics.poultry.pal.utils.PoultryPalUtil;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class MedicineScheduleService {
  public List<Medicine> generateBroilerMedicineSchedule(Date hatchDate, GrowingPhase growingPhase) {
    List<Medicine> medicines = new ArrayList<>();

    switch (growingPhase) {
      case BROODING_PHASE:
        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                1,
                7,
                "Stress pack",
                "Boost immunity and reduce stress",
                "5ml per liter of water",
                "Drinking water",
                "Daily",
                "Administer during the first 5 days to strengthen immunity.",
                PoultryPalUtil.addDays(hatchDate, 7),
                null,
                false,
                null,
                null,
                null,
                true));
        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                8,
                8,
                "Lasota",
                "Newcastle disease vaccine",
                "As per manufacturer instructions",
                "Drinking water or eye drop",
                "Single dose",
                "Administer via drinking water or eye drop as recommended. Ensure birds are healthy before vaccination.",
                PoultryPalUtil.addDays(hatchDate, 8),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                14,
                14,
                "Gumboro",
                "Gumboro disease vaccine (IBD)",
                "As per manufacturer instructions",
                "Drinking water",
                "Single dose",
                "Administer via drinking water as recommended. Ensure birds are healthy before vaccination.",
                PoultryPalUtil.addDays(hatchDate, 14),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                10,
                13,
                "Doxy-Max 50%",
                "Antibiotic for bacterial infections",
                "As per veterinarian's advice",
                "Drinking water",
                "Daily for 3-5 days",
                "Use only if signs of bacterial infection appear. Administer via drinking water.",
                PoultryPalUtil.addDays(hatchDate, 13),
                null,
                false,
                null,
                null,
                null,
                false));

        break;

      case GROWING_REARING_PHASE:
        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                17,
                24,
                "Cosumix",
                "Vitamin and mineral supplement",
                "5g per liter of water",
                "Drinking water",
                "Daily",
                "Administer during the last week of the growth phase.",
                PoultryPalUtil.addDays(hatchDate, 24),
                null,
                false,
                null,
                null,
                null,
                false));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                18,
                28,
                "Bedgen 40%",
                "Liver tonic and supportive supplement",
                "5g per liter of water",
                "Drinking water",
                "Daily",
                "Administer via drinking water daily during days 18-24 to support liver function and recovery from stress or disease.",
                PoultryPalUtil.addDays(hatchDate, 28),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                21,
                21,
                "Lasota",
                "Newcastle disease vaccine",
                "As per manufacturer instructions",
                "Drinking water or eye drop",
                "Single dose",
                "Administer via drinking water or eye drop as recommended. Ensure birds are healthy before vaccination.",
                PoultryPalUtil.addDays(hatchDate, 21),
                null,
                false,
                null,
                null,
                null,
                true));

        break;

      case PRODUCTION_FINISHING_PHASE:
        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                28,
                35,
                "Ropadiar Oregro",
                "Natural gut health and immunity booster (oregano oil based)",
                "5g per liter of water",
                "Drinking water",
                "As needed during hot weather",
                "Administer via drinking water as needed during hot weather or periods of stress to support gut health and reduce risk of intestinal infections.",
                PoultryPalUtil.addDays(hatchDate, 35),
                null,
                false,
                null,
                null,
                null,
                true));
        break;

      default:
        throw new IllegalArgumentException("Invalid growing phase: " + growingPhase);
    }

    return medicines;
  }

  public List<Medicine> generateLayerMedicineSchedule(Date hatchDate, GrowingPhase growingPhase) {
    List<Medicine> medicines = new ArrayList<>();

    switch (growingPhase) {
      case BROODING_PHASE:
        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                0,
                0,
                "Marek's Vaccine",
                "Prevent Marek's Disease",
                "Subcutaneous injection",
                "Injection",
                "Once",
                "Given at hatchery or on arrival (Day old).",
                PoultryPalUtil.addDays(hatchDate, 0),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                0,
                0,
                "Newcastle Disease Vaccine (NCD)",
                "Prevent Newcastle Disease",
                "Eyedrop or coarse spray",
                "Eyedrop/Spray",
                "Once",
                "Given on day-old chicks (Day old).",
                PoultryPalUtil.addDays(hatchDate, 0),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                14,
                14,
                "Infectious Bursal Disease (IBD or Gumboro)",
                "Prevent Infectious Bursal Disease",
                "Drinking water",
                "Drinking water",
                "Once",
                "First dose of Gumboro vaccine (14 days).",
                PoultryPalUtil.addDays(hatchDate, 14),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                18,
                18,
                "Newcastle Disease Vaccine (NCD)",
                "Booster for Newcastle Disease",
                "Fine spray",
                "Spray",
                "Once",
                "Boosts Newcastle protection (18 days).",
                PoultryPalUtil.addDays(hatchDate, 18),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                20,
                20,
                "Infectious Bursal Disease",
                "Booster for Infectious Bursal Disease",
                "Drinking water",
                "Drinking water",
                "Once",
                "Second dose of Gumboro vaccine (20 days).",
                PoultryPalUtil.addDays(hatchDate, 20),
                null,
                false,
                null,
                null,
                null,
                true));
        break;

      case GROWING_REARING_PHASE:
        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                42,
                42,
                "Newcastle Disease and Infectious Bronchitis",
                "Booster for Newcastle & Infectious Bronchitis",
                "Fine spray",
                "Spray",
                "Once",
                "Given around  day 42 (6 weeks).",
                PoultryPalUtil.addDays(hatchDate, 42),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                70,
                70,
                "Newcastle Vaccine",
                "Routine booster",
                "Fine spray",
                "Spray",
                "Once",
                "10-week Newcastle booster (10 weeks).",
                PoultryPalUtil.addDays(hatchDate, 70),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                84,
                84,
                "Infectious Coryza,  Fowl Pox and Infectious Laryngotracheitis",
                "Prevent Coryza, Fowl Pox and Infectious Laryngotracheitis",
                "Multiple routes",
                "Subcutaneous/Wing stab/Eyedrop",
                "Once",
                "12-week triple vaccination (12 weeks).",
                PoultryPalUtil.addDays(hatchDate, 84),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                91,
                91,
                "Avian Encephalomyelitis (AE) Vaccine",
                "Prevent AE",
                "Drinking water",
                "Drinking water",
                "Once",
                "Given around day 91 (13 weeks).",
                PoultryPalUtil.addDays(hatchDate, 91),
                null,
                false,
                null,
                null,
                null,
                true));

        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                98,
                98,
                "Newcastle Booster",
                "Final Newcastle booster before laying",
                "Fine spray",
                "Spray",
                "Once",
                "Given around day 98 (14 weeks).",
                PoultryPalUtil.addDays(hatchDate, 98),
                null,
                false,
                null,
                null,
                null,
                true));
        break;

      case PRODUCTION_FINISHING_PHASE:
        medicines.add(
            new Medicine(
                UUID.randomUUID().toString(),
                112,
                112,
                "NCD, IB, EDS and Coryza Vaccines",
                "Final vaccines before laying",
                "Intramuscular injection",
                "Injection",
                "Once",
                "Newcastle Disease (NCD), Infectious Bronchitis (IB), Egg Drop Syndrome (EDS), Infectious Coryza. Administered around day 112  (16 weeks).",
                PoultryPalUtil.addDays(hatchDate, 112),
                null,
                false,
                null,
                null,
                null,
                true));

        int boosterStartDay = 126;
        int boosterEndDay = 420;
        int boosterInterval = 42; //42 for every 6 weeks

        for (int day = boosterStartDay; day <= boosterEndDay; day += boosterInterval) {
          medicines.add(
              new Medicine(
                  UUID.randomUUID().toString(),
                  day,
                  day,
                  "Newcastle Booster",
                  "Maintain immunity during laying",
                  "Fine spray",
                  "Spray",
                  "Every 4–6 weeks",
                  "Repeat booster at day " + day,
                  PoultryPalUtil.addDays(hatchDate, day),
                  null,
                  false,
                  null,
                  null,
                  null,
                  true));
        }
        break;

      default:
        throw new IllegalArgumentException("Invalid growing phase: " + growingPhase);
    }

    return medicines;
  }
}
