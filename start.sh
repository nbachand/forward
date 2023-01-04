#!/bin/bash
#
# Starts a remote sbatch jobs and sets up correct port forwarding.
# Sample usage: bash start.sh sherlock/singularity-jupyter 
#               bash start.sh sherlock/singularity-jupyter /home/users/raphtown
#               bash start.sh sherlock/singularity-jupyter /home/users/raphtown

# Create ssh-mux (SSH multiplex) dir only if not exists
[[ ! -d dir ]] || mkdir ~/.ssh/control/%C

# Solution: Start SSH multiplexing session (works fine)
# https://unix.stackexchange.com/questions/50508/reusing-ssh-session-for-repeated-rsync-commands
ssh -nNf -o ControlMaster=yes -o ControlPath="~/.ssh/control/%C" nbachand@login.sherlock.stanford.edu

if [ ! -f params.sh ]
then
    echo "Need to configure params before first run, run setup.sh!"
    exit
fi
. params.sh

if [ "$#" -eq 0 ]
then
    echo "Need to give name of sbatch job to run!"
    exit
fi

if [ ! -f helpers.sh ]
then
    echo "Cannot find helpers.sh script!"
    exit
fi
. helpers.sh

NAME="${1:-}"

# The user could request either <resource>/<script>.sbatch or
#                               <name>.sbatch
SBATCH="$NAME.sbatch"

# set FORWARD_SCRIPT and FOUND
set_forward_script
check_previous_submit 'ControlPath="~/.ssh/control/%C"'

echo
echo "== Getting destination directory =="
RESOURCE_HOME="ssh -o 'ControlPath="~/.ssh/control/%C"' ${RESOURCE} pwd"
ssh -o 'ControlPath="~/.ssh/control/%C"' ${RESOURCE} mkdir -p $RESOURCE_HOME/forward-util

echo
echo "== Uploading sbatch script =="
rsync -e "ssh -o 'ControlPath="~/.ssh/control/%C"'" $FORWARD_SCRIPT ${RESOURCE}:$RESOURCE_HOME/forward-util/

# adjust PARTITION if necessary
set_partition
echo

echo "== Submitting sbatch =="

SBATCH_NAME=$(basename $SBATCH)
command="sbatch
    --job-name=$NAME
    --partition=$PARTITION
    --output=$RESOURCE_HOME/forward-util/$SBATCH_NAME.out
    --error=$RESOURCE_HOME/forward-util/$SBATCH_NAME.err
    --mem=$MEM
    --time=$TIME
    $RESOURCE_HOME/forward-util/$SBATCH_NAME $PORT \"${@:2}\""

echo ${command}
ssh -o 'ControlPath="~/.ssh/control/%C"' ${RESOURCE} ${command}

# Tell the user how to debug before trying
instruction_get_logs

# Wait for the node allocation, get identifier
get_machine 'ControlPath="~/.ssh/control/%C"'
echo "notebook running on $MACHINE"

sleep $CONNECTION_WAIT_SECONDS

setup_port_forwarding

echo "== Connecting to notebook =="

# Print logs for the user, in case needed
print_logs

echo
instruction_get_logs

echo 
echo "== Instructions =="
echo "1. Password, output, and error printed to this terminal? Look at logs (see instruction above)"
echo "2. Browser: http://$MACHINE:$PORT/ -> http://localhost:$PORT/..."
echo "3. To end session: bash end.sh ${NAME}"

# Finish SSH multiplexing session
ssh -O exit -o ControlPath="~/.ssh/control/%C" nbachand@login.sherlock.stanford.edu