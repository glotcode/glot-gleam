#!/bin/bash


(
    export DATABASE_URL=postgres://glot:glot@localhost:5432/glot

    cd glot_backend
    gleam run -m parrot
)
