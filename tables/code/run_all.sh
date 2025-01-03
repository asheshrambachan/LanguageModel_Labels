#!/bin/bash

echo "Generating tables for Prediction Task: Financial News Headlines"
Rscript ./tables/code/prediction_headlines.r

echo "Generating tables for Prediction Task: Congressional Legislation"
Rscript ./tables/code/prediction_legislation.r

echo "Generating tables for Estimation Task: Financial News Headlines"
Rscript ./tables/code/estimation_headlines.r

echo "Generating tables for Estimation Task: Congressional Legislation"
Rscript ./tables/code/estimation_legislation.r

