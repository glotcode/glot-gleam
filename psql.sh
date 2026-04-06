#!/bin/bash


(
    cd glot_backend
    docker exec -it glot_backend-postgres-1 psql -U glot
)


