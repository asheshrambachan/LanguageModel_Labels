#!/bin/bash

echo "Generating tables for Prediction Task: Financial News Headlines"
Rscript ./tables/code/prediction_headlines.r

echo "Generating tables for Prediction Task: Congressional Bills"
Rscript ./tables/code/prediction_cb.r

echo "Generating tables for Estimation Task: Financial News Headlines"
Rscript ./tables/code/estimation_headlines.r

echo "Generating tables for Estimation Task: Congressional Bills"
Rscript ./tables/code/estimation_cb.r

