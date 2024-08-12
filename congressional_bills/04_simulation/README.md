
## Usage on local machine
The `simulate_lhs_parallel.Rmd` file is not up to date. Use `simulate_lhs_parallel.R` and `simulate_rhs_parallel.R`.

## Usage on server
On your local machine, run the following in the terminal to copy the required files to the specified remote server:
```
cd ~/Documents/LanguageModel_Labels/congressional_bills/04_simulation
chmod +x copy_local2remote.sh 
./copy_local2remote.sh username@supply.mit.edu
ssh username@supply.mit.edu
```

you need to install `conda` first, make sure to set the default channel to conda-forge to use r-base=4.4.1 rather than default of 4.3.1.
```
conda update conda
conda config --add channels conda-forge
conda config --set channel_priority strict
```
On the remote server, create a new `r4.4.1` env:
```
conda create -n r4.4.1 r-base r-dplyr r-sandwich r-lmtest r-furrr
conda list
conda activate r4.4.1
cd ~/Documents/LanguageModel_Labels/congressional_bills/04_simulation
```
To start the simulation, change the `n_cores` and `rds_dir` in the Rscript, then run the following:
```
Rscript simulate_lhs_parallel.R 1>output.log 2>error.log &
```
The code generates `rds` files the specified `lhs_rds` folder.

## To-Dos:

- [ ] remove shell scripts
- [x] resolve issue with RHS simulation
- [x] ensure Rmd and R files are the same
- [x] comments + documentations for LHS
- [ ] comments + documentations for RHS
- [x] unify data structure for both RHS and LHS simulations
