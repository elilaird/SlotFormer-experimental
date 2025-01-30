#!/usr/bin/env zsh

TIME=${TIME:-0-04:00:00}
PARTITION=${PARTITION:-short}
JOB_TYPE=${JOB_TYPE:-jupyter}

GPU=${GPU:-1}
CPUS=${CPUS:-16}    
MEM=${MEM:-"16G"}


CONTAINER_DIR=${CONTAINER_DIR:-"/projects/coreyc/coreyc_mp_jepa/graph_world_models/containers"}
PROJECT_DIR=${PROJECT_DIR:-"${HOME}/Projects/SlotFormer-experimental"}
DATA_DIR=${DATA_DIR:-"/projects/coreyc/coreyc_mp_jepa/graph_world_models/data"}

DATETIME=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="output/${JOB_TYPE}_${DATETIME}_%j.out"

if [ "${JOB_TYPE}" = "jupyter" ]; then
    COMMAND="jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.allow_origin='*' --NotebookApp.token='' --NotebookApp.password=''"
else
    COMMAND="python test.py"
fi


# write sbatch script
echo "#!/usr/bin/env zsh
#SBATCH -J ${JOB_TYPE}
#SBATCH -A coreyc_coreyc_mp_jepa_0001
#SBATCH -o ${LOG_FILE}
#SBATCH -c ${CPUS} --mem=${MEM}     
#SBATCH --nodes=1
#SBATCH -G ${GPU}
#SBATCH --time=${TIME} 
#SBATCH --partition=${PARTITION}

module purge
module load conda
conda activate /users/ejlaird/.conda/envs/slotformer

srun \
--container-mounts=${PROJECT_DIR}:/work_dir,${DATA_DIR}:/data \
--container-workdir /work_dir \
bash -c \"${COMMAND}\"
" > ${JOB_TYPE}_${DATETIME}.sbatch

# submit sbatch script
sbatch ${JOB_TYPE}_${DATETIME}.sbatch

sleep 0.1
rm -f ${JOB_TYPE}_${DATETIME}.sbatch