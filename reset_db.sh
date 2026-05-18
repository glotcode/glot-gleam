#!/bin/bash


(
    cd glot_backend
    docker compose down
    docker compose up -d

    until docker exec glot_backend-postgres-1 pg_isready -U glot -d glot >/dev/null 2>&1
    do
        sleep 1
    done
)

