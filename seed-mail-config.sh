#!/usr/bin/env bash
# Inserts or updates the SMTP settings in the app_config collection (run on the server).
# Credentials come from the environment so they are never stored in the repo:
#
#   MAIL_USER='you@gmail.com' MAIL_PASS='app-password' \
#   POULTRY_MONGO_USER=admin POULTRY_MONGO_PASSWORD=secret ./seed-mail-config.sh
#
# Optional: MAIL_HOST (smtp.gmail.com) MAIL_PORT (587) MAIL_AUTH (true) MAIL_STARTTLS (true)
#           MONGO_CONTAINER (mongodb)  DB_NAME (poultry-pal-db)
# Restart the app afterwards: the email scheduler stays blocked after an authentication failure.
set -euo pipefail

: "${MAIL_USER:?Set MAIL_USER}"
: "${MAIL_PASS:?Set MAIL_PASS}"
: "${POULTRY_MONGO_USER:?Set POULTRY_MONGO_USER}"
: "${POULTRY_MONGO_PASSWORD:?Set POULTRY_MONGO_PASSWORD}"

MONGO_CONTAINER="${MONGO_CONTAINER:-mongodb}"
DB_NAME="${DB_NAME:-poultry-pal-db}"
export MAIL_HOST="${MAIL_HOST:-smtp.gmail.com}"
export MAIL_PORT="${MAIL_PORT:-587}"
export MAIL_AUTH="${MAIL_AUTH:-true}"
export MAIL_STARTTLS="${MAIL_STARTTLS:-true}"

docker exec -i \
  -e MAIL_HOST -e MAIL_PORT -e MAIL_AUTH -e MAIL_STARTTLS -e MAIL_USER -e MAIL_PASS \
  "$MONGO_CONTAINER" mongosh --quiet \
  -u "$POULTRY_MONGO_USER" -p "$POULTRY_MONGO_PASSWORD" --authenticationDatabase admin "$DB_NAME" \
  --eval '
const settings = {
  MAIL_HOST: process.env.MAIL_HOST,
  MAIL_PORT: process.env.MAIL_PORT,
  MAIL_AUTH: process.env.MAIL_AUTH,
  MAIL_STARTTLS: process.env.MAIL_STARTTLS,
  MAIL_USER: process.env.MAIL_USER,
  MAIL_PASS: process.env.MAIL_PASS,
};
const now = new Date();
for (const [code, description] of Object.entries(settings)) {
  db.app_config.updateOne(
    { code },
    {
      $set: { description, lastUpdateDate: now },
      $setOnInsert: { code, createDate: now, _class: "co.za.hlaluko.dynamics.poultry.pal.model.entity.lookups.AppConfig" },
    },
    { upsert: true },
  );
}
db.app_config.find({ code: /^MAIL_/ }, { _id: 0, code: 1, description: 1 }).forEach((d) => {
  if (d.code === "MAIL_PASS") d.description = "********";
  printjson(d);
});
'

echo "Done. Restart the app: docker restart poultry-pal"
