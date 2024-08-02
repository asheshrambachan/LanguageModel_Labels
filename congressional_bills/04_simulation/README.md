
## Usage on local machine
Use the markdown files `simulate_parallel.Rmd` and `evaluate_parallel.Rmd`

The files without `parallel` are older versions with incorrect implementation and will be deleted soon.

## Usage on server
On your local machine, run the following in the terminal to copy the required files to the specified remote server:
```
cd ~/Documents/LanguageModel_Labels/congressional_bills/04_simulation
chmod +x copy_local2remote.sh 
./copy_local2remote.sh username@supply.mit.edu
ssh username@supply.mit.edu
```

On the remote server, create a new `r_env` using `conda` (you need to install `conda` first if missing):
```
conda create -n r_env r-essentials r-base  r-dplyr r-sandwich r-lmtest r-furrr r-progressr
conda activate r_env
cd ~/Documents/LanguageModel_Labels/congressional_bills/04_simulation
```
To start the simulation, run the following:
```
Rscript simulate_lhs_parallel.R 1000 1000 25 1>output.log 2>error.log &
```
The passed arguments in order are `N B n_cores`. If `n_cores` is greater than what's available, the maximum number of available cores will be used.

The code generates `rds` files that are stored in `rds_N_B` folder in the same directory. 

## To-Dos:

- [ ] remove shell scripts
- [ ] resolve issue with RHS simulation
- [ ] ensure Rmd and R files are the same
- [ ] comments + documentations
