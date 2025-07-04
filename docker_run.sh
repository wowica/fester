#!/bin/bash

# Replace this with your Ogmios URL
# Use Demeter.run for a free instance.
OGMIOS_URL="ws://localhost:1337"

# Ensure the database is created and available.
DATABASE_URL="postgresql://postgres:postgres@host.docker.internal:5432/fester"

# Leaving this value unchanged is fine but keep in mind that it's not secure.
# If using phoenix, then mix phx.gen.secret will generate one.
SECRET_KEY_BASE="W3rPmh5P2Z3RlqIK9M/Q92Qo+9Lg1YZO0NU722814vgfe35QT/guwMNKD0xBGiXD"

docker run -it --rm --add-host host.docker.internal:host-gateway \
  -p 4000:4000 \
  -e OGMIOS_URL=$OGMIOS_URL \
  -e DATABASE_URL=$DATABASE_URL \
  -e SECRET_KEY_BASE=$SECRET_KEY_BASE \
  fester