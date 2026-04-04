package co.za.hlaluko.dynamics.poultry.pal.service;

import co.za.hlaluko.dynamics.poultry.pal.model.dto.Feed;
import co.za.hlaluko.dynamics.poultry.pal.model.dto.GrowingPhase;
import co.za.hlaluko.dynamics.poultry.pal.utils.PoultryPalUtil;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class FeedScheduleService {
  public List<Feed> generateLayerFeedSchedule(Date hatchDate, GrowingPhase growingPhase) {
    List<Feed> feeds = new ArrayList<>();

    switch (growingPhase) {
      case GrowingPhase.BROODING_PHASE:
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                1,
                7,
                "Starter",
                "High protein for early growth and development.",
                "Feed 11g/day to reach 75g body weight.",
                PoultryPalUtil.addDays(hatchDate, 7),
                null,
                false,
                null,
                null,
                null,
                0.075));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                8,
                14,
                "Starter",
                "Support early development and immunity.",
                "Feed 17g/day to reach 130g body weight.",
                PoultryPalUtil.addDays(hatchDate, 14),
                null,
                false,
                null,
                null,
                null,
                0.130));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                15,
                21,
                "Starter",
                "Continued support for chick growth.",
                "Feed 22g/day to reach 195g body weight.",
                PoultryPalUtil.addDays(hatchDate, 21),
                null,
                false,
                null,
                null,
                null,
                0.195));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                22,
                28,
                "Starter",
                "Nutritional boost for rapid development.",
                "Feed 28g/day to reach 275g body weight.",
                PoultryPalUtil.addDays(hatchDate, 28),
                null,
                false,
                null,
                null,
                null,
                0.275));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                29,
                35,
                "Starter",
                "Support growth in the last week of starter phase.",
                "Feed 35g/day to reach 371g body weight.",
                PoultryPalUtil.addDays(hatchDate, 35),
                null,
                false,
                null,
                null,
                null,
                0.371));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                36,
                42,
                "Starter",
                "Final week of starter feed to reach full chick development.",
                "Feed 41g/day to reach 474g body weight.",
                PoultryPalUtil.addDays(hatchDate, 42),
                null,
                false,
                null,
                null,
                null,
                0.474));
        break;

      case GrowingPhase.GROWING_REARING_PHASE:
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                43,
                49,
                "Grower",
                "Moderate protein for body development.",
                "Feed 47g/day to reach 578g body weight.",
                PoultryPalUtil.addDays(hatchDate, 49),
                null,
                false,
                null,
                null,
                null,
                0.578));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                50,
                56,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 51g/day to reach 679g body weight.",
                PoultryPalUtil.addDays(hatchDate, 56),
                null,
                false,
                null,
                null,
                null,
                0.679));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                57,
                63,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 55g/day to reach 775g body weight.",
                PoultryPalUtil.addDays(hatchDate, 63),
                null,
                false,
                null,
                null,
                null,
                0.775));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                64,
                70,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 58g/day to reach 867g body weight.",
                PoultryPalUtil.addDays(hatchDate, 70),
                null,
                false,
                null,
                null,
                null,
                0.867));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                71,
                77,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 60g/day to reach 956g body weight.",
                PoultryPalUtil.addDays(hatchDate, 77),
                null,
                false,
                null,
                null,
                null,
                0.956));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                78,
                84,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 64g/day to reach 1042g body weight.",
                PoultryPalUtil.addDays(hatchDate, 84),
                null,
                false,
                null,
                null,
                null,
                1.042));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                85,
                91,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 65g/day to reach 1126g body weight.",
                PoultryPalUtil.addDays(hatchDate, 91),
                null,
                false,
                null,
                null,
                null,
                1.126));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                92,
                98,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 68g/day to reach 1207g body weight.",
                PoultryPalUtil.addDays(hatchDate, 98),
                null,
                false,
                null,
                null,
                null,
                1.207));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                99,
                105,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 70g/day to reach 1286g body weight.",
                PoultryPalUtil.addDays(hatchDate, 105),
                null,
                false,
                null,
                null,
                null,
                1.286));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                106,
                112,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 71g/day to reach 1363g body weight.",
                PoultryPalUtil.addDays(hatchDate, 112),
                null,
                false,
                null,
                null,
                null,
                1.363));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                113,
                119,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 72g/day to reach 1437g body weight.",
                PoultryPalUtil.addDays(hatchDate, 119),
                null,
                false,
                null,
                null,
                null,
                1.437));
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                120,
                126,
                "Grower",
                "Support muscle growth and prep for maturity.",
                "Feed 75g/day to reach 1464–1554g body weight.",
                PoultryPalUtil.addDays(hatchDate, 126),
                null,
                false,
                null,
                null,
                null,
                1.509)); // average of 1464-1554
        break;

      case GrowingPhase.PRODUCTION_FINISHING_PHASE:
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                127,
                133,
                "Layer",
                "High calcium feed for egg production.",
                "Start of egg laying expected after 18 weeks.",
                PoultryPalUtil.addDays(hatchDate, 133),
                null,
                false,
                null,
                null,
                null,
                1.509));
        break;

      default:
        throw new IllegalArgumentException("Invalid growing phase: " + growingPhase);
    }

    return feeds;
  }

  public List<Feed> generateBroilerFeedSchedule(Date hatchDate, GrowingPhase growingPhase) {
    List<Feed> feeds = new ArrayList<>();

    switch (growingPhase) {
      case BROODING_PHASE:
        // Day 1 to Day 18: Starter Mash
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                1,
                18,
                "Starter",
                "Provide high protein (20-24%) for early growth.",
                "Each chick will consume 1 kg of Starter Mash over the first 18 days.",
                PoultryPalUtil.addDays(hatchDate, 18),
                null,
                false,
                null,
                null,
                null,
                0.5)); // 500g = 0.5kg
        break;

      case GROWING_REARING_PHASE:
        // Day 18 to Day 32: Grower Mash
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                18,
                32,
                "Grower",
                "Provide protein (18-20%) for growth and weight gain.",
                "Each chicken will consume 2 kg of Grower Mash over these 14 days.",
                PoultryPalUtil.addDays(hatchDate, 32),
                null,
                false,
                null,
                null,
                null,
                1.7)); // 1700g = 1.7kg
        break;

      case PRODUCTION_FINISHING_PHASE:
        // Day 32 to Day 45: Finisher Mash
        feeds.add(
            new Feed(
                UUID.randomUUID().toString(),
                32,
                45,
                "Finisher",
                "Continue providing protein (18-20%) to complete weight gain.",
                "Each chicken will consume 1 kg of additional Finisher Mash over these 13 days.",
                PoultryPalUtil.addDays(hatchDate, 45),
                null,
                false,
                null,
                null,
                null,
                2.5)); // 2500g = 2.5kg
        break;

      default:
        throw new IllegalArgumentException("Invalid growing phase: " + growingPhase);
    }

    return feeds;
  }
}
