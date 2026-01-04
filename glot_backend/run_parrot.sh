#!/bin/bash

export DATABASE_URL=postgres://glot:glot@localhost:5432/glot

gleam run -m parrot
