#!/bin/bash

echo "Starting Prediction Task: Congressional Bills..."
./prediction_cb/code/run_all.sh

echo "Starting Prediction Task: Financial News Headlines..."
./prediction_headlines/code/run_all.sh

echo "Starting Estimation Task: Congressional Bills..."
./estimation_cb/code/run_all.sh

echo "Starting Estimation Task: Financial News Headlines..."
# ./estimation_headlines/code/run_all.sh

echo "Starting to generate all figures..."
./figures/code/run_all.sh

echo "Starting to generate all figures..."
./tables/code/run_all.sh