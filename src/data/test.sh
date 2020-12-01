#!/bin/bash

LIW82=/pylon5/med200002p/liw82
input_parser() {
    # Load input parser functions
    . "./opts.shlib" "$@"

    opts_AddMandatory '--subjectPath' 'subjectPath' 'path to file with subject IDs' "a required value; path to a file with the IDs of the subject to be processed must be absolute path (e.g. /pylon5/med200002p/liw82/KLU/90*/80*)" "--subject" "--subjectList" "--subjList"
    opts_AddOptional '--printcom' 'RUN' 'do (not) perform a dray run' "an optional value; If RUN is not a null or empty string variable, then this script and other scripts that it calls will simply print out the primary commands it otherwise would run. This printing will be done using the command specified in the RUN variable, e.g., echo" "" "--PRINTCOM" "--printcom"

    opts_ParseArguments "$@"

    # Display the parsed/default values
    opts_ShowValues
}
usage() {
    CURDIR="$(pwd)"
    # debug for folders 
    echo $FS_LICENSE
    echo $CURDIR
    echo $LIW82

    # header text
    echo "
$log_ToolName: Queueing script for running MPP on Slurm-based computing clusters

Usage: $log_ToolName
                    --subjectPath=<path>                Path to folder with subject images must be absolute
                    [--printcom=command]                if 'echo' specified, will only perform a dry run.

    PARAMETERs are [ ] = optional; < > = user supplied value

    Values default to running the example with sample data
"
    # automatic argument descriptions
    opts_ShowArguments
}

setup() {
    SSH=/usr/bin/ssh
    
    # The directory holding the data for the subject correspoinding ot this job
    # pass the path to each scan for each subject to each job -lw
    scanIDs=$(basename $subjectPath)
    subjectIDs=$(basename $(dirname $subjectPath))
    BASE=$LIW82/KLU/$subjectIDs/$scanIDs
    IMAGEDIR="$BASE/converted/Hires/${scanIDs}_Hires.nii"
    
    # Node directory that where computation will take place
    SUBJECTDIR=$BASE/step_01_Freesurfer/
    #rm -r $SUBJECTDIR
    #mkdir -p $SUBJECTDIR

    NCPU=`scontrol show hostnames $SLURM_JOB_NODELIST | wc -l`
    echo ------------------------------------------------------
    echo ' This job is allocated on '$NCPU' cpu(s)'
    echo ------------------------------------------------------
    echo SLURM: sbatch is running on $SERVER
    echo SLURM: server calling directory is $SERVERDIR
    echo SLURM: node is $NODE
    echo SLURM: node working directory is $SUBJECTDIR
    echo SLURM: job name is $SLURM_JOB_NAME
    echo SLURM: master job identifier of the job array is $SLURM_ARRAY_JOB_ID
    echo SLURM: job array index identifier is $SLURM_ARRAY_TASK_ID
    echo SLURM: job identifier-sum master job ID and job array index-is $SLURM_JOB_ID
    echo ' '
    echo ' '


    # Location of subject folder
    studyFolderBasename=`basename $BASE`;

    # Report major script control variables 
	echo "ID: $subjectIDs"
    echo "Scan: $scanIDs"
    echo "Base directory: $BASE"
    echo "Image directory: $IMAGEDIR"
    echo "Subject directory: $SUBJECTDIR"
	echo "printcom: ${RUN}"



    # Create log folder
    LOGDIR="${SUBJECTDIR}/logs/"
    mkdir -p $LOGDIR
}
input_parser "$@"
setup
echo $subjectPath > $LOGDIR/$subjectID.out