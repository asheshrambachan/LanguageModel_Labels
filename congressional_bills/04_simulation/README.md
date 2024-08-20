
## Usage on local machine


## Usage on server

1. Create `combinations_lhs.csv` by running the corresponding part in `pre_post_simulation.Rmd` notebook.

2. Copy the required file from your local machine to the server preserving rep directory structure. Alternatively, you can use the provided shell code to that for you `copy_local2remote.sh`. To run the code, type the following in the terminal. Make sure to replace `username` and `servername` with appropriate values.
```
cd ~/Documents/LanguageModel_Labels/congressional_bills/04_simulation
chmod +x copy_local2remote.sh 
./copy_local2remote.sh username@servername.mit.edu
ssh username@servername.mit.edu
```

3. Ensure you have `conda` on the server. If not install it. Make sure to set the default channel to `conda-forge` to use `r-base=4.4.1` rather than default of `4.3.1`. The latter has incompatibility issues when using `dplyr`'s `slice/filter/indexing` and `furrr::future_map`. To do that, use the following:
```
conda update conda
conda config --add channels conda-forge
conda config --set channel_priority strict
```

4. On the remote server, create a new `r4.4.1` env:
```
conda create -n r4.4.1 r-base r-dplyr r-sandwich r-lmtest r-furrr r-Matrix
conda list
conda activate r4.4.1
cd ~/Documents/LanguageModel_Labels/congressional_bills/04_simulation
```

5. Before starting the simulation, change the `n_cores` and `rds_dir` in the `simulate_lhs_parallel.R` script. Then run the following:
```
Rscript simulate_lhs_parallel.R 1>output.log 2>error.log &
```

6. The code generates `rds` files the specified `rds_lhs` folder. Once completed copy them to your local machine

7. Run the merging cells in `pre_post_simulations.Rmd` to merge the `rds` files and generate the `simulations_averaged_lhs.csv`.

## To-Dos:

- [ ] add instructions for usage on local machines
- [ ] add details on the 2 runs for lhs (or rerun the code once)
- [ ] remove shell scripts
- [x] resolve issue with RHS simulation
- [x] ensure Rmd and R files are the same
- [x] comments + documentations for LHS
- [ ] comments + documentations for RHS
- [x] unify data structure for both RHS and LHS simulations
