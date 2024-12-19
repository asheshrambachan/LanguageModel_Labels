#!/bin/bash

echo "Generating figures for Prediction Task: Financial News Headlines"
Rscript ./figures/code/prediction_headlines.r

echo "Generating figures for Prediction Task: Congressional Bills"
Rscript ./figures/code/prediction_cb.r

echo "Generating figures for Estimation Task: Financial News Headlines"
Rscript ./figures/code/estimation_headlines.r

echo "Generating figures for Estimation Task: Congressional Bills"
Rscript ./figures/code/estimation_cb.r
