package co.za.hlaluko.dynamics.poultry.pal.repository;

import co.za.hlaluko.dynamics.poultry.pal.model.entity.CoopArchive;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface CoopArchiveRepository extends MongoRepository<CoopArchive, String> {}
