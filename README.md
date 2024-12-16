# Large Language Models: An Applied Econometric Framework

This repository contains the code, data, and outputs associated with the paper "[Large Language Models: An Applied Econometric Framework](https://arxiv.org/pdf/2412.07031)" by Jens Ludwig, Sendhil Mullainathan, and Ashesh Rambachan.

TODO: Add two lines about the paper.

## Citation

If you use this repository, please cite the paper:
```
@article{ludwig2024largelanguagemodelsapplied,
    title={Large Language Models: An Applied Econometric Framework}, 
    author={Jens Ludwig and Sendhil Mullainathan and Ashesh Rambachan},
    year={2024},
    journal={arXiv preprint arXiv:2412.07031},
    url={https://arxiv.org/abs/2412.07031}, 
}
```

## Repository Structure

This repository is organized to facilitate the replication of results presented in the paper. The subdirectories are structured based on task type (prediction or estimation) and data source (Congressional bills or financial headlines):
- `prediction_cb/`: Code and data for prediction tasks involving Congressional bills data.
- `prediction_headlines/`: Code and data for prediction tasks involving financial headlines.
- `estimation_cb/`: Code and data for estimation tasks involving Congressional bills data.
- `estimation_headlines/`: Code and data for estimation tasks involving financial headlines.
- `figures/`: Code and outputs for generating figures presented in the paper for both data sources.
- `tables/`: Code and outputs for generating tables presented in the paper for both data sources.

## Using the Repository

1. Create a Conda environment with all packages needed for both Python and R code:
    ```bash
    cd path/to/LanguageModel_Labels
    conda update conda
    conda config --set channel_priority strict
    conda env create -f conda_llm_env.yaml
    conda activate llm_env
    ```
2. Follow the instructions in the respective subdirectory `README.md` files to replicate the data generation process
    - [Prediction Task: Congressional bills](./prediction_cb)
    - [Prediction Task: financial headlines]()
    - [Estimation Task: Congressional bills](./estimation_cb)
    - [Estimation Task: financial headlines](./estimation_headlines)
3. Run the provided scripts in the [`figures/code/`](./figures/code) directory to generate all figures. Results will be saved in [`figures/output/`](./figures/output).
4. Run the provided scripts in the [`tables/code/`](./tables/code) directory to generate all tables. Results will be saved in [`tables/output/`](./tables/output).
