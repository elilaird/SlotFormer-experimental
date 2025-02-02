#!/bin/bash

# SBATCH file can't directly take command args
# as a workaround, I first use a sh script to read in args
# and then create a new .slrm file for SBATCH execution

#######################################################################
# An example usage:
#     GPUS=1 CPUS_PER_GPU=8 MEM_PER_CPU=5 QOS=normal ./scripts/sbatch_run.sh rtx6000 \
#         test-sbatch test.py ddp --params params.py --fp16 --ddp --cudnn

# video prediction obj3d example
# GPUS=1 CPUS_PER_GPU=8 MEM_PER_CPU=5 QOS=normal TIME=00:30:00 ./scripts/sbatch_run.sh short test_sbatch slotformer/video_pre
# diction/test_vp.py ddp --params slotformer/video_prediction/configs/slotformer_obj3d_params.py --fp16 --cudnn
#######################################################################

# read args from command line
GPUS=${GPUS:-1}
CPUS_PER_GPU=${CPUS_PER_GPU:-8}
MEM_PER_CPU=${MEM_PER_CPU:-5}
QOS=${QOS:-normal}
TIME=${TIME:-0}

PY_ARGS=${@:5}
PARTITION=$1
JOB_NAME=$2
PY_FILE=$3
DDP=$4

SLRM_NAME="${JOB_NAME/\//"_"}"
LOG_DIR=checkpoints/"$(basename -- $JOB_NAME)"
DATETIME=$(date "+%Y-%m-%d_%H:%M:%S")
LOG_FILE=$LOG_DIR/${SLRM_NAME}_${DATETIME}_%j.log
CPUS_PER_TASK=$((GPUS * CPUS_PER_GPU))


# set up log output folder
mkdir -p $LOG_DIR

# python runner for DDP
if [[ $DDP == "ddp" ]];
then
  PORT=$((29501 + $RANDOM % 100))  # randomly select a port
  PYTHON="python -m torch.distributed.launch --nproc_per_node=$GPUS --master_port=$PORT"
else
  PYTHON="python"
fi

# write to new file
echo "#!/usr/bin/env zsh

# set up SBATCH args
#SBATCH --job-name=$SLRM_NAME
#SBATCH -A coreyc_coreyc_mp_jepa_0001
#SBATCH --output=$LOG_FILE
#SBATCH --partition=$PARTITION                       # self-explanatory, set to your preference (e.g. gpu or cpu on MaRS, p100, t4, or cpu on Vaughan)
#SBATCH --cpus-per-task=$CPUS_PER_TASK               # self-explanatory, set to your preference
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem-per-cpu=${MEM_PER_CPU}G                # self-explanatory, set to your preference
#SBATCH -G $GPUS                             # NOTE: you need a GPU for CUDA support; self-explanatory, set to your preference 
#SBATCH --nodes=1
#SBATCH --time=$TIME                                 # running time limit, 0 as unlimited

# log some necessary environment params
echo \$SLURM_JOB_ID                       # log the job id
echo \$SLURM_JOB_PARTITION                # log the job partition

echo $CONDA_PREFIX                       # log the active conda environment 

python --version                         # log Python version
gcc --version                            # log GCC version

# run python file
$PYTHON $PY_FILE $PY_ARGS

" >> ./run-${SLRM_NAME}.sbatch

# run the created file
sbatch run-${SLRM_NAME}.sbatch

# delete it
sleep 0.1
rm -f run-${SLRM_NAME}.sbatch