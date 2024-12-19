# Large Language Models: An Applied Econometric Framework

This repository contains the code, data, and outputs associated with the paper "[Large Language Models: An Applied Econometric Framework](https://arxiv.org/pdf/2412.07031)" by Jens Ludwig, Sendhil Mullainathan, and Ashesh Rambachan.

## Repository Structure

If you are only interested in generating prompts[^1], querying, and decoding the LLM responses, you first need to **Add your `OPENAI_API_KEY`** to `.env` file. To do that:
            1. Go to the [OpenAI API Keys](https://platform.openai.com/settings/profile?tab=api-keys) page.
            2. Create a new API key and copy the generated key.
            3. Replace `your key` in the command below with your actual API key, then run it to create a `.env` file and add your OpenAI API key.
                ```bash
                cd path/to/congressional_bills
                echo 'OPENAI_API_KEY="your key"' > .env
                ```
                
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
    - [Estimation Task: financial headlines](./headlines)
    
3. Run the provided scripts in the [`figures/code/`](./figures/code) directory to generate all figures. Results will be saved in [`figures/output/`](./figures/output).

4. Run the provided scripts in the [`tables/code/`](./tables/code) directory to generate all tables. Results will be saved in [`tables/output/`](./tables/output).

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


## References

- Adler, E Scott and John Wilkerson, _"Congressional Bills Project: 1947-2016,"_ NSF 00880066 and 00880061 2024. Accessed July 5, 2024. [`http://congressionalbills.org/download.html`](http://congressionalbills.org/download.html).

- Egami, Naoki, Musashi Hinck, Brandon M. Stewart, and Hanying Wei, _"Using imperfect surrogates for downstream inference: design-based supervised learning for social science applications of large language models,"_ in Advances in Neural Information Processing Systems, Vol. 36, 2023. Replication code available at: [`https://osf.io/gjt87/`]( https://osf.io/gjt87/)

- Wilkerson, John, E. Scott Adler, Bryan D. Jones, Frank R. Baumgartner, Guy Freedman, Sean M. Theriault, Alison Craig, Derek A. Epp, Cheyenne Lee, and Miranda E. Sullivan, _``Policy Agendas Project: Congressional Bills,''_ 2023. Accessed July 5, 2024. [`https://www.comparativeagendas.net/#congressional_hearings`](https://www.comparativeagendas.net/#congressional_hearings).

- Jones, Bryan D., Frank R. Baumgartner, Sean M. Theriault, Derek A. Epp, Cheyenne Lee, and Miranda E. Sullivan, “Policy Agendas Project: Codebook,” 2023. Accessed July 5, 2024. [`https://minio.la.utexas.edu/compagendas/codebookfiles/Codebook_PAP_2019.pdf`](https://minio.la.utexas.edu/compagendas/codebookfiles/Codebook_PAP_2019.pdf).
