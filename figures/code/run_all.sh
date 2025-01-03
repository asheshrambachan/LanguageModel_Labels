#!/bin/bash

echo "Generating figures for Prediction Task: Financial News Headlines"
Rscript ./figures/code/prediction_headlines.r

echo "Generating figures for Prediction Task: Congressional Legislation"
Rscript ./figures/code/prediction_legislation.r

echo "Generating figures for Estimation Task: Financial News Headlines"
Rscript ./figures/code/estimation_headlines.r

echo "Generating figures for Estimation Task: Congressional Legislation"
Rscript ./figures/code/estimation_legislation.r
