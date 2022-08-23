#!/bin/bash

PORT=$1
NOTEBOOK_DIR=$2
cd $NOTEBOOK_DIR

source /home/groups/gorle/codes/miniconda3/etc/profile.d/conda.sh

conda activate cascade_env

jupyter notebook --no-browser --port=$PORT
