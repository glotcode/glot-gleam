#!/bin/bash


(
    cd glot_backend
    docker compose down
    docker compose up -d
)


