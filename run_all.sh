#!/bin/bash

echo "Starting Prediction Task: Financial News Headlines..."
chmod +x ./prediction_headlines/code/run_all.sh
./prediction_headlines/code/run_all.sh

echo "Starting Prediction Task: Congressional Bills..."
chmod +x ./prediction_cb/code/run_all.sh
./prediction_cb/code/run_all.sh

echo "Starting Estimation Task: Financial News Headlines..."
# chmod +x ./estimation_headlines/code/run_all.sh
# ./estimation_headlines/code/run_all.sh

echo "Starting Estimation Task: Congressional Bills..."
chmod +x ./estimation_cb/code/run_all.sh
./estimation_cb/code/run_all.sh

echo "Starting to generate all figures..."
chmod +x ./figures/code/run_all.sh
./figures/code/run_all.sh

echo "Starting to generate all figures..."
chmod +x ./tables/code/run_all.sh
./tables/code/run_all.sh