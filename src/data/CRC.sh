#!/bin/bash

#SBATCH --image=<path_to_image>
# or skip the above line and call singularity exec <path_to_image> <command> instead of just <command> in the main portion of the code
#SBATCH --error=./logs/slurm/slurm-%A_%a.err
#SBATCH --output=./logs/slurm/slurm-%A_%a.out

module purge # Make sure the modules environment is sane
module load singularity
# or use #SBATCH --export=all module purge module load gcc/5.2.0 fsl/5.0.11-centos matlab/R2019b singularity
export FS_LICENSE=/pylon5/med200002p/liw82/license.txt
# The hostname from which sbatch was invoked (e.g. cluster)
SERVER=$SLURM_SUBMIT_HOST
# The name of the node running the job script (e.g. node10)
NODE=$SLURMD_NODENAME
# The directory from which sbatch was invoked (e.g. proj/DBN/src/data/MPP)
SERVERDIR=$SLURM_SUBMIT_DIR

# This function gets called by opts_ParseArguments when --help is specified
usage() {
    CURDIR="$(pwd)"
    echo $FS_LICENSE
    echo $CURDIR
    echo $SCRATCH
    # header text
    echo "
$log_ToolName: Queueing script for running MPP on Slurm-based computing clusters

Usage: $log_ToolName
                    --studyFolder=<path>                Path to folder with subject images
                    --subjects=<path or list>           File path or list with subject IDs
                    [--printcom=command]                if 'echo' specified, will only perform a dry run.

    PARAMETERs are [ ] = optional; < > = user supplied value

    Values default to running the example with sample data
"
    # automatic argument descriptions
    opts_ShowArguments
}

input_parser() {
    # Load input parser functions
    . "./opts.shlib" "$@"

    opts_AddMandatory '--studyFolder' 'studyFolder' 'raw data folder path' "a required value; is the path to the study folder holding the raw data. Don't forget the study name (e.g. /mnt/storinator/edd32/data/raw/ADNI)"
    opts_AddMandatory '--subjects' 'subjects' 'path to file with subject IDs' "a required value; path to a file with the IDs of the subject to be processed (e.g. /mnt/storinator/edd32/data/raw/ADNI/subjects.txt)" "--subject" "--subjectList" "--subjList"
    opts_AddOptional '--printcom' 'RUN' 'do (not) perform a dray run' "an optional value; If RUN is not a null or empty string variable, then this script and other scripts that it calls will simply print out the primary commands it otherwise would run. This printing will be done using the command specified in the RUN variable, e.g., echo" "" "--PRINTCOM" "--printcom"

    opts_ParseArguments "$@"

    # Display the parsed/default values
    opts_ShowValues
}


setup() {
    SCP=/usr/bin/scp
    SSH=/usr/bin/ssh

    # Looks in the file of IDs and get the correspoding subject ID for this job
    SubjectID=$(head -n $SLURM_ARRAY_TASK_ID "$subjects" | tail -n 1)
    # The directory holding the data for the subject correspoinding ot this job
    # pass the path to each scan for each subject to each job -lw
    SUBJECTDIR=$studyFolder/raw/$SubjectID
    # Node directory that where computation will take place
    NODEDIR=/pylon5/med200002p/liw82/KLU/${SubjectID}/step_01_Freesurfer/

    mkdir -p $NODEDIR
    echo Transferring files from server to compute node $NODE

    # Copy MPP scripts from server to node, creating whatever directories required
    $SCP -r $SERVERDIR $NODEDIR

    NCPU=`scontrol show hostnames $SLURM_JOB_NODELIST | wc -l`
    echo ------------------------------------------------------
    echo ' This job is allocated on '$NCPU' cpu(s)'
    echo ------------------------------------------------------
    echo SLURM: sbatch is running on $SERVER
    echo SLURM: server calling directory is $SERVERDIR
    echo SLURM: node is $NODE
    echo SLURM: node working directory is $NODEDIR
    echo SLURM: job name is $SLURM_JOB_NAME
    echo SLURM: master job identifier of the job array is $SLURM_ARRAY_JOB_ID
    echo SLURM: job array index identifier is $SLURM_ARRAY_TASK_ID
    echo SLURM: job identifier-sum master job ID and job array index-is $SLURM_JOB_ID
    echo ' '
    echo ' '

    # Copy DATA from server to node, creating whatever directories required
    $SCP -r $SUBJECTDIR $NODEDIR

    # Location of subject folders (named by subjectID)
    studyFolderBasename=`basename $studyFolder`;

    # Report major script control variables to usertart_auto_complete)cho "studyFolder: ${SERVERDATADIR}"
	echo "subject:${SubjectID}"
	echo "class: ${class}"
	echo "domainX: ${domainX}"
	echo "domainY: ${domainY}"
	echo "MNIRegistrationMethod: ${MNIRegistrationMethod}"
    echo "windowSize: ${windowSize}"
	echo "printcom: ${RUN}"

    # Create log folder
    LOGDIR="${NODEDIR}/logs/"
    mkdir -p $LOGDIR

}

# Join function with a character delimiter
join_by() { local IFS="$1"; shift; echo "$*"; }

main() {
    ###############################################################################
	# Inputs:
	#
	# Scripts called by this script do NOT assume anything about the form of the
	# input names or paths. This batch script assumes the following raw data naming
	# convention, e.g.
	#
	# ${SubjectID}/${class}/${domainX}/${SubjectID}_${class}_${domainY}1.nii.gz
	# ${SubjectID}/${class}/${domainX}/${SubjectID}_${class}_${domainY}2.nii.gz
    # ...
	# ${SubjectID}/${class}/${domainX}/${SubjectID}_${class}_${domainY}n.nii.gz
    ###############################################################################


    # Detect Number of domain X Images and build list of full paths to them
    Xs=($(find ${NODEDIR}/${SubjectID}/${class} -type f | grep "${domainX}.\/${SubjectID}_-_${class}_-_${domainX}.\.nii\.gz$"))
    numXs=`echo "${#Xs[@]}"`
    echo "Found ${numXs} ${domainX} Images for subject ${SubjectID}"
    xInputImages=`join_by '@' ${Xs[@]}`

    # Detect Number of domain Y Images and build list of full paths to them
    Ys=($(find ${NODEDIR}/${SubjectID}/${class} -type f | grep "${domainY}.\/${SubjectID}_-_${class}_-_${domainY}.\.nii\.gz$"))
    numYs=`echo "${#Ys[@]}"`
    echo "Found ${numYs} ${domainY} Images for subject ${SubjectID}"
    yInputImages=`join_by '@' ${Ys[@]}`

    cd $NODEDIR

    # Submit to be run the MPP.sh script with all the specified parameter values
    $NODEDIR/MPP/MPP.sh \
        --studyName="$studyFolderBasename" \
        --subject="$SubjectID" \
        --class=$class \
        --domainX="$domainX" \
        --domainY="$domainY" \
        --x="$xInputImages" \
        --y="$yInputImages" \
        --xTemplate="$xTemplate" \
        --xTemplateBrain="$xTemplateBrain" \
        --xTemplate2mm="$xTemplate2mm" \
        --yTemplate="$yTemplate" \
        --yTemplateBrain="$yTemplateBrain" \
        --yTemplate2mm="$yTemplate2mm" \
        --templateMask="$TemplateMask" \
        --template2mmMask="$Template2mmMask" \
        --brainSize="$BrainSize" \
        --MNIRegistrationMethod="$MNIRegistrationMethod" \
        --windowSize="$windowSize" \
        --customBrain="$CustomBrain" \
        --brainExtractionMethod="$BrainExtractionMethod" \
        --FNIRTConfig="$FNIRTConfig" \
        --printcom=$RUN \
        1> $LOGDIR/$SubjectID.out \
        2> $LOGDIR/$SubjectID.err
}

cleanup() {

    permanent_dir=preprocessed/${BrainExtractionMethod}/${MNIRegistrationMethod}/${class}/${SubjectID}
    log_dir=${studyFolder}/logs/${BrainExtractionMethod}/${MNIRegistrationMethod}/${class}
    slurm_log_dir=${SERVERDIR}/logs/slurm/${BrainExtractionMethod}/${MNIRegistrationMethod}/${class}

    echo ' '
    echo Transferring files from node to server
    echo "Writing files in permanent directory ${studyFolder}/${permanent_dir}"

    mkdir -p ${studyFolder}/${permanent_dir}
    $SCP  -r ${NODEDIR}/${studyFolderBasename}/${permanent_dir}/* ${studyFolder}/${permanent_dir}/

    mkdir -p ${log_dir}
    $SCP  -r ${NODEDIR}/logs/* ${log_dir}/

    mkdir -p ${slurm_log_dir}
    mv $SERVERDIR/logs/slurm/slurm-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.err ${slurm_log_dir}/slurm-${SubjectID}.err
    mv $SERVERDIR/logs/slurm/slurm-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out ${slurm_log_dir}/slurm-${SubjectID}.out
    $SCP ${slurm_log_dir}/slurm-${SubjectID}.err ${log_dir}/
    $SCP ${slurm_log_dir}/slurm-${SubjectID}.out ${log_dir}/

    echo ' '
    echo 'Files transfered to permanent directory, clean temporary directory and log files'
    rm -rf /pylon5/med200002p/liw82/KLU/${SubjectID}/step_01_Freesurfer/
    rm ${slurm_log_dir}/slurm-${SubjectID}.err
    rm ${slurm_log_dir}/slurm-${SubjectID}.out

    crc-job-stats.py # gives stats of job, wall time, etc.
}

early() {
	echo ' '
	echo ' ############ WARNING:  EARLY TERMINATION #############'
	echo ' '
}

input_parser "$@"
setup
main
cleanup

trap 'early; cleanup' SIGINT SIGKILL SIGTERM SIGSEGV

# happy end
exit 0
