#!/bin/bash

echo "Starting Prediction Task: Financial News Headlines..."
bash prediction_headlines/code/run_all.sh

echo "Starting Prediction Task: Congressional Legislation..."
bash prediction_legislation/code/run_all.sh

echo "Starting Estimation Task: Financial News Headlines..."
bash estimation_headlines/code/run_all.sh

echo "Starting Estimation Task: Congressional Legislation..."
bash estimation_legislation/code/run_all.sh

echo "Starting to generate all figures..."
bash figures/code/run_all.sh

echo "Starting to generate all figures..."
bash tables/code/run_all.sh