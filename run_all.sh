#!/bin/bash

echo "Starting Prediction Task: Financial News Headlines..."
chmod +x ./prediction_headlines/code/run_all.sh
./prediction_headlines/code/run_all.sh

echo "Starting Prediction Task: Congressional Legislation..."
chmod +x ./prediction_legislation/code/run_all.sh
./prediction_legislation/code/run_all.sh

echo "Starting Estimation Task: Financial News Headlines..."
chmod +x ./estimation_headlines/code/run_all.sh
./estimation_headlines/code/run_all.sh

echo "Starting Estimation Task: Congressional Legislation..."
chmod +x ./estimation_legislation/code/run_all.sh
./estimation_legislation/code/run_all.sh

echo "Starting to generate all figures..."
chmod +x ./figures/code/run_all.sh
./figures/code/run_all.sh

echo "Starting to generate all figures..."
chmod +x ./tables/code/run_all.sh
./tables/code/run_all.sh