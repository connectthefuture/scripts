#!/bin/bash
#

let VERBOSE=0
let b_FORCE=0
let b_BOUND=0
WRITECURVATUREFILES=""
CONTINUOUSFORM=""

declare -i Gb_vertexAreaNormalize=0
declare -i Gb_vertexAreaWeigh=0
VERTEXAREAWEIGH=""
VERTEXAREANORMALIZE=""
FRAC=""

MRIS_CURVATURE_STATS="mris_curvature_stats"
EXPDIR="./"
# List of target subject dirs
SUBJECTS="31.1 34 36.7 38.1 38.4 39.72 801"
PRINCIPLEMAPLIST="K,H,K1,K2,S,C,BE"
WAVELETPOWERS="0 1 2 3 4 5 6 7"
BOUND=0
STAGES="12345678"
G_SYNOPSIS="

 NAME

	mris_curvature_stats.bash

 SYNOPSIS

	mris_curvature_stats.bash				\\
				[-e <experimentTopDir>]		\\
				[-t <stages>] [-f]		\\
				[-v <verbosity>]		\\
				[-w <powerList>]		\\
				[-i <bound>]			\\
				[-p <principleMapList>]		\\
				[-s]				\\
				[-c]				\\
				[-N] [-W] [-F]			\\	
				[-m <mris_curvature_stats>]	\\	
				<SUBJECT1> [<SUBJECT2> ... <SUBJECTn>]
		
 DESCRIPTION

	'mris_curvature_stats.bash' is a wrapper script about an underlying
	'mris_curvature_stats' process. For practical purposes, it is an
	updated version of 'mris_waveletsProcess_doBatch.bash', with a slightly
	expanded and improved functionality. 

	It can be seen as the 'setup' step in a curvature analysis stream. 
	Essentially, this script creates and analyzes FreeSurfer curvature 
	files containing various principle curvature mappings, and then groups
	these specific curvature files together in sub directories.

	By default, this script will, for each subject, run the curvature 
	analysis 'mris_curvature_stats', capturing the output in a series of 
	text files. It will also combine, per subject, information in a
	spread-sheet like table of results as a function of wavelet 
	spectral powers. These tables are grouped according to the curvature	
	maps performed.

	Additionally, it can also group curvature files together for simplified
	analysis through the 'lzg_summary.m' and 'curvs_plot.m' scripts.

	The particulars of its behaviour are controlled by the <stages>
	command line argument. 

 ARGUMENTS

	-e <experimentTopDir> (optional - default '$EXPDIR')
	The directory housing the <subjectDirList>.

	-t <stages>
	The stages to perform. See the POSTCONDITIONS.

	-f (optional) (Default: $b_FORCE)
	Force <stages>. By default, the script will not execute a stage if
	it has already been run for the current subject. This can be forced
	by using the '-f' flag.

	-v <level> (optional) (Default: $VERBOSE)
	Verbosity level.

	-w <powerList> (optional) (Default: $WAVELETPOWERS)
	A list of wavelet powers to process.

	-i <bound> (optional) (Default: $BOUND)
	Bound the histogram analysis between the absolute constraint <bound>.
	This means that the histogram is calculated between -<bound>... <bound>.

	-p <principleMapList> (optional) (Default: $PRINCIPLEMAPLIST)
	A comma separated list of principle map functions to process.

	-m <mris_curvature_stats> (optional) (Default: $MRIS_CURVATURE_STATS)
	The name of the 'backend' process to analyze the curvatures. This 
	should probably never be set, unless you want to use an appropriate
	substitute - particularly if the version of 'mris_curvature_stats'
	in the FreeSurfer tree is possibly outdated and you have a newer
	one available.

	-s (optional) (Default: '$WRITECURVATUREFILES')
	If specified, toggle the '--writeCurvatureFiles' flag on the underlying
	'mris_curvature_stats' process to save all curvature files.

	-c (optional) (Default: '$CONTINUOUSFORM')
	If specified, toggle the '--continuous' flag on the underlying
	'mris_curvature_stats' process. This selects the continuous Second 
        Order Fundamental form for calculating the prinicple curvatures.

        -N -W -F (optional)
        If specified, pass a --vertexAreaNormalize (-N) or a --vertexAreaWeigh
        (-W) to the underlying 'mris_curvature_stats' process. If these are 
        specified, the <9abc> stages are superfluous.

	The '-F' flag toggles the N and W to use fractional vertex area
	measures. See 'mris_curvature_stats -u' for more information on
	fractional calculations.

	<SUBJECT1> [<SUBJECT2> ... <SUBJECTn>]
	List of Subjects to process. At least one subject should be specified.


 PRECONDITIONS

	o SUBJECTS_DIR must be set.

	o The SUBJECT[1..n] arguments *must* have the
	  same names as specific subject IDs in SUBJECTS_DIR.	

 POSTCONDITIONS

	o Most output is written to each input SUBJECTs' working directory
	  corresponding to the SUBJECT1 [<SUBJECT2>... <SUBJECTn>]. This
	  output includes text-based files of the curvature analysis, as well
	  as copies and links to any created FreeSurfer type curvature
	  files.

	o The <stages> is a string of hex numbers - in this case '0' to 'c'
	  that denotes the specific actions to perform (note: rh implies
	  'right hemisphere', lh implies 'left hemisphere').

		1 - Process the SUBJECT for right-hemisphere 
		    K, H, k1, and k2 principle curvatures. Also process
		    the principle curvature functions S, C, and BE. Optionally
		    create FreeSurfer curvature files of all curvature maps.
		2 - Process the SUBJECT for left-hemisphere 
		    K, H, k1, and k2 principle curvatures. Also process
		    the principle curvature functions S, C, and BE. Optionally
		    create FreeSurfer curvature files of all curvature maps.
		3 - Summarize the rh data in spreadsheet form.
		4 - Summarize the lh data in spreadsheet form.
		5 - Group all the rh principle surfaces together in each
		    SUBJECT working directory.
		6 - Group all the lh principle surfaces together in each
		    SUBJECT working directory.
		7 - Create a rh.inflated.recon? for each ?h.smoothwm.recon?
		8 - Create a lh.inflated.recon? for each ?h.smoothwm.recon?

		9 - Multiply the rh curvature files with rh.area
		a - Multiply the lh curvature files with lh.area
		b - Divide   the rh curvature files with rh.area
		c - Divide   the lh curavture files with lh.area 

	  Stages <9abc> change the actual curvature files, modifying each
	  curvature value according to the stage meaning. It is only
	  meaningful to run either stages <9a> OR <bc>. These stages use
	  the 'mris_calc' executable to change the curvature values and
	  also copy the relevant ?h.area files to each subject directory.

	  Note that by default these stages are postprocessing states and 
	  will not affect the summary data prepared by earlier stages. In
	  order to update earlier stages it will be necessary to rerun stages
	  34 again. 

	  Alternatively either the -W or -N flags can be used -- in which case
	  the underlying 'mris_curvature_stats' will normalize/weigh the 
	  curvatures.

	o Resultant log/spreadsheet files are stored in each subjects' working
	  directory and are recorded in several files:

		 K-<subj>-<hemi>-WSP<powerLevel>.log
		 H-<subj>-<hemi>-WSP<powerLevel>.log
		k1-<subj>-<hemi>-WSP<powerLevel>.log
		k2-<subj>-<hemi>-WSP<powerLevel>.log
		 S-<subj>-<hemi>-WSP<powerLevel>.log
		 C-<subj>-<hemi>-WSP<powerLevel>.log
		BE-<subj>-<hemi>-WSP<powerLevel>.log

	  For each of the above, stages 7 and 8 will create a 
	  <principle>-<subj>-<hemi>-WSPall.log summary file that consists of 
	  the following five columns:

		<power level> <min> <max> <mean> <std> <bounded>

 SEE ALSO

	o mris_waveletsProcess_doBatch
	o self_construct.bash

 HISTORY

 07 September 2007
 o Expanded from 'mris_waveletsProcess_doBatch'.
	
 30 January 2008
 o Added stages for vertex area normalization / weighting.

 14 February 2008
 o Added 'Frac' handling.
 o Improved output logging.
"

###\\\
# Globals are in capital letters. Immutable globals are prefixed by 'G'.
###///
G_SELF=`basename $0`
G_PID=$$
G_LC=50
G_RC=20

# Actions
A_noSubjectsDirVar="checking environment"
A_noSubjectsDir="checking environment"
A_noSubjectBase="checking base subject dir"
A_noSubjectExp="checking experiment subject dir"
A_comargs="checking command line arguments" 
A_comargsE="checking command line argument '-e'" 
A_noComSpec="checking for command spec"
A_noExpDir="checking on the passed directory"
A_noHemisphere="checking the '-h' parameter"
A_noRhCurv="linking the right hemisphere curvature file"
A_noLhCurv="linking the left hemisphere curvature file"
A_gaussian="generating the Gaussian curvatures"
A_metaLog="checking the meta log file"
A_noMrisStats="checking on the 'mris_curvature_stats' binary"
A_mrisStatsprocess="running the 'mris_curvature_stats' binary"
A_areaCopy="copying a surface area file"
A_surfaceBak="creating surface file backups"

# Error messages
EM_noSubjectsDirVar="it seems that the SUBJECTS_DIR environment var is not set."
EM_noSubjectsDir="it seems that the SUBJECTS_DIR refers to an invalid directory."
EM_noSubjectBase="I couldn't find a subject in the base directory."
EM_noSubjectExp="I couldn't find a subject in the experiment directory."
EM_noComSpec="no command spec was found."
EM_comargsE="I couldn't find the <experimentTopDir> specifier."
EM_noComSpec="no command spec was found."
EM_noExpDir="I couldn't find the <experimentTopDir>."
EM_noHemisphere="I couldn't find a valid specifier. Use either 'lh' or 'rh'."
EM_noRhCurv="I couldn't link the file."
EM_noLhCurv="I couldn't link the file."
EM_gaussian="some error occurred."
EM_metaLog="it seems as though this stage has already run.\n\tYou can force execution with a '-f'."
EM_noMrisStats="I can't find the file on your current path."
EM_mrisStatsprocess="the program died unexpectedly."
EM_areaCopy="the copy failed."
EM_surfaceBak="the backup failed."

# Error codes
EC_noSubjectsDir=1
EC_noSubjectBase=2
EC_noSubjectExp=3
EC_noComSpec=4
EC_comargsE=12
EC_noComSpec=13
EC_noExpDir=23
EC_noHemisphere=30
EC_noRhCurv=31
EC_noLhCurv=32
EC_gaussian=40
EC_metaLog=80
EC_noMrisStats=90
EC_mrisStatsprocess=100
EC_areaCopy=110
EC_surfaceBack=120

# Defaults
D_whatever=

###\\\
# Function definitions
###///

function verbosity_check
{
	#
	# DESC
	# If verbosity level is non-zero, set output to stdout, else
	# set to /dev/null
	#

	exec 6>&1 
	if (( VERBOSE )) 
	then
		exec >&1
	else
		exec > "/dev/null"
	fi
}

function shut_down
# $1: Exit code
{
        rm -f $HEADER
        echo -e "\n$G_SELF:\n\tShutting down with code $1.\n"
        exit $1
}

function synopsis_show
{
	echo "USAGE:"
	echo "$G_SYNOPSIS"
}
                   
function error
# $1: Action
# $2: Error string
# $3: Exit code
{
	echo -e "\n$G_SELF:\n\tSorry, but there seems to be an error." >&2
	echo -e "\tWhile $1,"                                      >&2
	echo -e "\t$2\n"                                           >&2
	shut_down $3
}                

function fatal
# $1: variable name - used to construct action/error string/exit code
{
	local stem=$1
	eval action=\$A_$stem
	eval errorString=\$EM_$stem
	eval exitCode=\$EC_$stem
	error "$action" "$errorString" "$exitCode"
}

function warn
# $1: Action
# $2: Warn string
# $3: Default value
{
	echo -e "\n$G_SELF: WARNING\n" 			>&2
	echo -e "\tWhile $1,"                           >&2
	echo -e "\t$2\n"                                >&2
	echo -e "\tSetting default to '$3'\n"		>&2
}                

function NOP
{
    	#
    	# DESC
    	#	Do nothing!
    
    return 0
}

function NOP_ret
{
   	#
	# ARGS
	# $1		in/out		a variable that is directly
	#					returned
	#
	# DESC
	# Does nothing other than "reflect" a passed variable back to
	# the caller.
	#

	return $1

}

function ret_check
{
	# ARGS
	# $1 		in		return value to check
	#
	# DESC
	# Checks for the passed return value, and echoes a
	# conditional to stdout. Returns this value back to
	# the main program.
	#
	
	local ret=$1
		
	if [[ $ret != "0" ]] ; then
		printf "%20s\n" "[ failure ]"
	else
		printf "%20s\n" "[ ok ]"
	fi
	return $ret
}

function statusPrint
{
	# ARGS
	# $1		in		message to print
	# $2		in		possible trailing character or string
	#
	# DESC
	# Prints a status message on the left of the console.
	#

	local status=$1
	local ctrlN=$2

	printf "%*s$ctrlN" $G_LC "$status"
}

function resultPrint
{
	# ARGS
	# $1		in		message to print
	#
	# DESC
	# Prints a message on the right of the console in square
	# brackets.
	#

	local msg=$1

	printf "%*s\n" $G_RC "[ $msg ]"
}

function fileExist_check
{
	#
	# ARGS
	# $1 		in		file to check
	#
	# DESC
	# Checks for the existence of a file, and echoes a
	# conditional to stdout. Returns this value back to
	# the main program:
	#	0: no error (file does exist)
	#	1: some error (file does not exist)
	#
	
	local file=$1
	
	if [[ ! -f $file ]] ; then
		printf "%20s\n" "[ failure ]"
		return 1
	else
		printf "%20s\n" "[ ok ]"
		return 0
	fi
}

function dirExist_check
{
	#
	# ARGS
	# $1 		in		dir to check
	#
	# DESC
	# Checks for the existence of a dir, and echoes a
	# conditional to stdout. Returns this value back to
	# the main program:
	#	0: no error (file does exist)
	#	1: some error (file does not exist)
	#
	
	local dir=$1
	
	if [[ ! -d $dir ]] ; then
		printf "%20s\n" "[ failure ]"
		return 1
	else
		printf "%20s\n" "[ ok ]"
		return 0
	fi
}

function stage_alreadyRun
{
	local stage=$1
	local logFile=$2

	echo $(cat $logFile | awk -F \| '{print $3'} | grep $stage | wc -l)
}

function stage_check
{
	local stage=$1
	local logFile=$2

	if [[ -f $logFile ]] ; then
		if (( !b_FORCE && $(stage_alreadyRun $stage $logFile) )) ; then
			fatal metaLog
		fi
	fi
}

function stage_stamp
{
	local stage=$1
	local logFile=$2

        echo -e "$(date) $(hostname) | $G_SELF | Stage "$stage" | ok" >>\
		"$logFile"
}

function fileWrite
{
	#
	# ARGS
	# $1		in		<fileName> to write
	# $2		in		<spectralPower> value
	# $3		in		<min> value
	# $4		in		<max> value
	# $5		in		<mean> value
	# $6		in		<std> value
	# $7		in		<bounded> value
	#
	# DESC
	# Pads input arguments into <fileName>.
	#

	local	fileName=$1
	local	min=$2
	local	max=$3
	local	mean=$4
	local	std=$5
	local	bounded=$6
	
	printf "%12s"	"$min"		 > $fileName
	printf "%12s"	"$max"		>> $fileName
	printf "%12s"	"$mean"		>> $fileName
	printf "%12s"	"$std"		>> $fileName
	printf "%12s\n"	"$bounded"	>> $fileName
}

function principleMaps_process
{
	#
	# ARGS
	# $1		in		hemisphere
	#
	# DESCRIPTION
	# For each spectral power in $WAVELETPOWERS, perform
	# a curvature analysis.
	#

	local hemi=$1

	cd $EXPDIR
	BOUNDARGS=""
	if (( b_BOUND )) ; then
		BOUNDARGS=" -i -$BOUND -j $BOUND "
	fi
	for SUBJ in $SUBJECTS ; do
	    cd ${EXPDIR}/$SUBJ
	    for spectralPower in $WAVELETPOWERS ; do
		stage_check "$STAGE-$SUBJ-$hemi-$spectralPower" ${G_SELF}.log
		if (( $spectralPower == 0 )) ; then
		    statusPrint						\
		    "Generating principle maps based on '$SUBJ/surf/$hemi.smoothwm'"
		    SURFACE="smoothwm"
		else
		    statusPrint						\
		    "Calculating principle maps for wavelet power $spectralPower"
		    SURFACE="smoothwm.recon$spectralPower"
		fi
		VERTEXAREA=""
		if (( Gb_vertexAreaNormalize )) ; then
		    VERTEXAREA="${VERTEXAREANORMALIZE}$FRAC"
		fi
		if (( Gb_vertexAreaWeigh)) ; then
		    VERTEXAREA="${VERTEXAREAWEIGH}$FRAC"
		fi
		CMD="$MRIS_CURVATURE_STATS 			\
			$BOUNDARGS				\
			$WRITECURVATUREFILES			\
			$CONTINUOUSFORM				\
			$VERTEXAREA				\
			-m -h 11 -G -F $SURFACE			\
			$SUBJ $hemi 		        	\
			2>error.log"
                stage_stamp "RUN $(echo $CMD | tr '\n' ' ')" ${G_SELF}.log 
                stats=$(eval $CMD) || fatal mrisStatsprocess
		ret_check $?
                echo "$stats" > ${G_SELF}.stage1.log

		if (( $(echo $WRITECURVATUREFILES | wc -l)  )) ; then
		    statusPrint "FreeSurfer curvature files saved"
		    ret_check $?
                    statusPrint "Copying to local directory" "\n"
                    for principle in $PRINCIPLEMAPLIST ; do
                        statusPrint     $principle
			SURF=$SUBJECTS_DIR/$SUBJ/surf/${hemi}.${SURFACE}.${principle}.crv
                        cp $SURF .
                        ret_check $?
                    done
		fi

		for principle in $PRINCIPLEMAPLIST; do
		    printf "%50s\n" "Analyzing for $principle..."
		    min=$(echo "$stats" | grep -i "$principle Min" |	\
				 awk '{print $3}' )
		    max=$(echo "$stats" | grep -i "$principle Max" |	\
				 awk '{print $3}' )
		    mean=$(echo "$stats" | grep -i "$principle <mean>" |	\
				 awk '{print $7}' )
		    std=$(echo "$stats" | grep -i "$principle <mean>" |	\
				 awk '{print $9}' )
		    bounded=$(echo "$stats" | grep -i "$principle ratio" |	\
				 awk '{print $4}' )
		    statusPrint "Min" ; 	resultPrint $min
		    statusPrint "Max" ; 	resultPrint $max
		    statusPrint "Mean" ; 	resultPrint $mean
		    statusPrint "Std" ; 	resultPrint $std
		    statusPrint "Bounded" ; 	resultPrint $bounded
		    fileName="${principle}-$SUBJ-$hemi-WSP${spectralPower}.log"
		    statusPrint "Writing $fileName"
		    fileWrite 	$fileName				\
				$min $max $mean $std $bounded
		    ret_check $?
		done
		stage_stamp "$STAGE-$SUBJ-$hemi-$spectralPower" ${G_SELF}.log
	    done
	    cd $EXPDIR
	done
}

function principleMaps_summarise
{
    #
    # ARGS
    # $1		in		hemisphere
    #
    # DESCRIPTION
    # For each spectral power in $WAVELETPOWERS, summarize
    # the results of the curvature analysis in a spreadsheet
    # friendly format.
    #
    # Summaries are organised in increasing wavelet order, and
    # per principle maps across subjects.
    #

    local hemi=$1
    local count=0

    cd $EXPDIR
    for spectralPower in $WAVELETPOWERS ; do
	for principle in $PRINCIPLEMAPLIST ; do
	    let count=0
	    for SUBJ in $SUBJECTS ; do
		cd $EXPDIR/$SUBJ
		stage_check "$STAGE-$SUBJ-$hemi-$spectralPower-$principle" ${G_SELF}.log
		inFile="${principle}-$SUBJ-$hemi-WSP${spectralPower}.log"
		outFile="${principle}-all-$hemi-WSP${spectralPower}.log"
		outWFile="${principle}-$SUBJ-$hemi-WSPall.log"
		if (( !count )) ; then echo "" > $outFile ; fi
		statusPrint "($spectralPower: $SUBJ, $principle)"
		printf "%s\t" 	"$spectralPower" 	>> $outFile 
		printf "%s\t" 	"$spectralPower" 	>> $outWFile 
		stats=$(cat "$inFile")
		printf "%s\n"	"$stats"		>> $outFile	
		printf "%s\n"	"$stats"		>> $outWFile	
		ret_check $?
		count=$(expr $count + 1)
		stage_stamp "$STAGE-$SUBJ-$hemi-$spectralPower-$principle" ${G_SELF}.log
	    done
	done
    done
}

function inflated_create
{
	#
	# ARGS
	# $1		in		hemisphere
	#
	# DESCRIPTION
	# For each spectral power in $WAVELETPOWERS, create 
	# an 'inflated' surface from the 'smoothwm' surface.
	#

	local hemi=$1
	local count=0

	cd $EXPDIR
	for SUBJ in $SUBJECTS ; do
	    for spectralPower in $WAVELETPOWERS ; do
		stage_check "$STAGE-$SUBJ-$hemi-$spectralPower" 	\
				$EXPDIR/$SUBJ/${G_SELF}.log
		cd $EXPDIR/$SUBJ >/dev/null
		printf "%50s" "Inflating power $spectralPower..."
		ret_inflate=$(mris_inflate 				\
				${hemi}.smoothwm.recon$spectralPower	\
				${hemi}.inflated.recon$spectralPower	\
				2>./mris_inflate-$STAGE-$SUBJ-$hemi-$spectralPower.log
				)
		ret_check $?
		stage_stamp "$STAGE-$SUBJ-$hemi-$spectralPower" 	\
				$EXPDIR/$SUBJ/${G_SELF}.log
	    done
	    cd $EXPDIR
	done
}

function surfaces_modify
{
	#
	# ARGS
	# $1		in		hemisphere
	# $2		in		mris_calc operation
	#
	# DESCRIPTION
	# For each curvature file in <hemisphere>.*crv, modify
	# according to $2 and <hemisphere>.area
	#

	local hemi=$1
	local op=$2

	cd $EXPDIR
	for SUBJ in $SUBJECTS ; do
		stage_check "$STAGE-$SUBJ-$hemi-$spectralPower" 	\
				$EXPDIR/$SUBJ/${G_SELF}.log
		cd $EXPDIR/$SUBJ >/dev/null
		
	        printf "%50s\n"	"Subject: $SUBJ"
		printf "%50s" 	"Copying $1.area"
		cp $SUBJECTS_DIR/$SUBJ/surf/$1.area .
		ret_check $? || fatal areaCopy

		printf "%50s" 	"Backing up all $1*.crv files..."
		mkdir $1.crv-$G_PID
		cp $1.*.crv $1.crv-$G_PID
		ret_check $? || fatal surfaceBak

		for SURF in ${hemi}*crv ; do
		    printf "%50s"	"mris_calc $SURF $op ${hemi}.area"
		    ret_mris_calc=$(mris_calc				\
				-o $SURF 				\
				${hemi}.crv-$G_PID/$SURF 		\
				$op					\
 				${hemi}.area 2>/dev/null)
		    ret_check $?
		done
		stage_stamp "$STAGE-$SUBJ-$hemi-$spectralPower" 	\
				$EXPDIR/$SUBJ/${G_SELF}.log
		cd $EXPDIR
	done
}

function principleMapFiles_group
{
	#
	# ARGS
	# $1		in		hemisphere
	#
	# DESCRIPTION
	# For each spectral power in $WAVELETPOWERS, copy the relevant
	# curvature files to $SUBJ working dirs, and also link to 
	# a more traditional FreeSurfer-ish name.
	#

	local hemi=$1
	local count=0

	cd $EXPDIR
	for SUBJ in $SUBJECTS ; do
	    for spectralPower in $WAVELETPOWERS ; do
		stage_check "$STAGE-$SUBJ-$hemi-$spectralPower" 	\
				$EXPDIR/$SUBJ/${G_SELF}.log
		cd $EXPDIR/$SUBJ 2>/dev/null
		statusPrint "Grouping from power $spectralPower..." "\n"
		for principle in $PRINCIPLEMAPLIST ; do
		    statusPrint "$principle"
		    if (( spectralPower == "0" )) ; then
			RECON=""
		    else
			RECON=".recon${spectralPower}"
		    fi
		    # Copy the curvature files to subject directory
		    cp $SUBJECTS_DIR/$SUBJ/surf/${hemi}.smoothwm${RECON}.${principle}.crv .
		    # Give then a more traditional FreeSurfer-ish name
		    ln -s ${hemi}.smoothwm${RECON}.${principle}.crv \
			  ${hemi}.smoothwm${RECON}.${principle}
		    ret_check $?
		done
		stage_stamp "$STAGE-$SUBJ-$hemi-$spectralPower" 	\
				$EXPDIR/$SUBJ/${G_SELF}.log
	    done
	    cd $EXPDIR
	done
}

###\\\
# Process command options
###///

while getopts e:v:t:fm:w:i:scp:WNF option ; do 
	case "$option"
	in
		e) EXPDIR=$OPTARG 				;;
		v) let VERBOSE=$OPTARG 				;;
		t) STAGES=$OPTARG 				;;
		f) b_FORCE=1 					;;
		w) WAVELETPOWERS=$OPTARG			;;
		s) WRITECURVATUREFILES="--writeCurvatureFiles"	;;
		c) CONTINUOUSFORM="--continuous"		;;
		i) BOUND=$OPTARG			
		   let b_BOUND=1				;;
		p) PRINCIPLEMAPLIST=$OPTARG			;;		
		m) MRIS_CURVATURE_STATS=$OPTARG			;;
		W) Gb_vertexAreaWeigh=1
		   VERTEXAREAWEIGH="--vertexAreaWeigh"		;;
		N) Gb_vertexAreaNormalize=1
		   VERTEXAREANORMALIZE="--vertexAreaNormalize"	;;
		F) FRAC="Frac"					;;
		\?) synopsis_show 
		    exit 0;;
	esac
done


verbosity_check
topDir=$(pwd)

statusPrint	"Checking for SUBJECTS_DIR env variable"
b_subjectsDir=$(set | grep SUBJECTS_DIR | wc -l)
if (( !b_subjectsDir )) ; then
	fatal noSubjectsDirVar
fi
ret_check $?

statusPrint 	"Checking for SUBJECTS_DIR directory"
dirExist_check $SUBJECTS_DIR || fatal noSubjectsDir

statusPrint	"Checking for <experimentTopDir>"
dirExist_check $EXPDIR || mkdir -p $EXPDIR
cd $EXPDIR ; EXPDIR=$(pwd) ; cd $topDir

ALLARGS=$*
shift $(($OPTIND - 1))
SUBJECTLIST=$*
b_SUBJECTLIST=$(echo $SUBJECTLIST| wc -w)
if (( b_SUBJECTLIST )) ; then
        SUBJECTS=$SUBJECTLIST
fi

statusPrint	"Checking <subjectList> in SUBJECTS_DIR" "\n"
for SUBJ in $SUBJECTS ; do
	statusPrint "$SUBJ"
	dirExist_check ${SUBJECTS_DIR}/$SUBJ/ || fatal noSubjectBase
done

statusPrint	"Checking <subjectList> in EXPDIR" "\n"
for SUBJ in $SUBJECTS ; do
	statusPrint "$SUBJ"
	dirExist_check ${EXPDIR}/$SUBJ/ || mkdir $SUBJ
done

statusPrint	"Checking which stages to process"
barr_stage=([1]=0 [2]=0 [3]=0 [4]=0 [5]=0 [6]=0 [7]=0 [8]=0 [9]=0 [10]=0 [11]=0 [12]=0)
for i in $(seq 1 9) ; do
	b_test=$(expr index $STAGES "$i")
	if (( b_test )) ; then b_flag="1" ; else b_flag="0" ; fi
	barr_stage[$i]=$b_flag
done
for i in a b c; do
        b_test=$(expr index "$STAGES" "$i")
        if (( b_test )) ; then
            if [[ $i == "a" ]] ; then barr_stage[10]="1" ; fi
            if [[ $i == "b" ]] ; then barr_stage[11]="1" ; fi
            if [[ $i == "c" ]] ; then barr_stage[12]="1" ; fi
        fi
done
ret_check $?

PRINCIPLEMAPLIST=$(echo $PRINCIPLEMAPLIST | tr ',' ' ')
statusPrint 	"principle map list: $PRINCIPLEMAPLIST"
ret_check $?

statusPrint	"Checking for 'mris_curvature_stats' binary"
dummy=$(type -all $MRIS_CURVATURE_STATS  2>/dev/null)
b_notExist=$?
if (( b_notExist )) ; then fatal noMrisStats ; else ret_check $b_notExist ; fi

for SUBJ in $SUBJECTS ; do
    STAMPLOG=$EXPDIR/$SUBJ/${G_SELF}.log
    stage_stamp "0 | ($topDir) $G_SELF $ALLARGS" $STAMPLOG
done

if (( ${barr_stage[1]} )) ; then
	STAGE=1
	echo "$(date) | Stage 1 - rh curvature processing"
	principleMaps_process rh
fi

if (( ${barr_stage[2]} )) ; then
	STAGE=2
	echo "$(date) | Stage 2 - lh curvature processing"
	principleMaps_process lh
fi

if (( ${barr_stage[3]} )) ; then
	STAGE=3
	echo "$(date) | Stage 3 - rh curvature summarizing"
	principleMaps_summarise rh
fi

if (( ${barr_stage[4]} )) ; then
	STAGE=4
	echo "$(date) | Stage 4 - lh curvature summarizing"
	principleMaps_summarise lh
fi

if (( ${barr_stage[5]} )) ; then
	STAGE=5
	echo "$(date) | Stage 5 - grouping all rh principle map files"
	principleMapFiles_group rh
fi

if (( ${barr_stage[6]} )) ; then
	STAGE=6
	echo "$(date) | Stage 6 - grouping all lh principle map files"
	principleMapFiles_group lh
fi

if (( ${barr_stage[7]} )) ; then
	STAGE=7
	echo "$(date) | Stage 7 - creating rh inflated.recon surfaces"
	inflated_create rh
fi

if (( ${barr_stage[8]} )) ; then
	STAGE=8
	echo "$(date) | Stage 8 - creating lh inflated.recon surfaces"
	inflated_create lh
fi

if (( ${barr_stage[9]} )) ; then
	STAGE=9
	echo "$(date) | Stage 9 - weighing rh surfaces with rh.area"
	surfaces_modify rh mul
fi

if (( ${barr_stage[10]} )) ; then
	STAGE=a
	echo "$(date) | Stage 10 - weighing lh surfaces with lh.area"
	surfaces_modify lh mul
fi

if (( ${barr_stage[11]} )) ; then
	STAGE=b
	echo "$(date) | Stage 11 - normalizing rh surfaces with rh.area"
	surfaces_modify rh div
fi

if (( ${barr_stage[12]} )) ; then
	STAGE=c
	echo "$(date) | Stage 12 - normalizing lh surfaces with lh.area"
	surfaces_modify lh div
fi


printf "%50s" "Cleaning up"
shut_down 0

