#!/bin/bash
#
# Copyright 2010 Rudolph Pienaar, Dan Ginsburg, FNNDSC
# Childrens Hospital Boston
#
# GPL v2
#
# pacs_pull.bash -- General purpose PACS query/retrieve
#                   text-based front end.
#
#

# "include" the set of common script functions
source common.bash
declare -i Gi_verbose=1
declare -i Gb_queryOnly=1
declare -i Gb_final=0
declare -i Gb_metaInfoPrinted=0
declare -i Gb_dateSpecified=0
declare -i Gb_seriesRetrieve=0
declare -i Gb_institution=0

# Column formatting (from common.bash)
G_LC=30
G_RC=50

# User searchable fields
# Fields initialised with "-x" must be specified by the user
# when running this script
GLST_PATIENTID=""
GLST_PATIENTSNAME=""
G_PATIENTID=""
G_PATIENTSNAME=""
G_QUERYRETRIEVELEVEL=""
G_MODALITY="MR"
G_PATIENTSNAME=""
G_SERIESDESCRIPTION=""
G_STUDYINSTANCEUID=""
G_SCANDATE=""

G_FINDSCUSTUDYSTD=/tmp/${G_SELF}_${G_PID}_findscu_study.std
G_FINDSCUSTUDYERR=/tmp/${G_SELF}_${G_PID}_findscu_study.err
G_FINDSCUSERIESSTD=/tmp/${G_SELF}_${G_PID}_findscu_series.std
G_FINDSCUSERIESERR=/tmp/${G_SELF}_${G_PID}_findscu_series.err

G_INSTITUTION=CHB
G_AETITLE=rudolphpienaar
G_QUERYHOST=134.174.12.21
G_QUERYPORT=104
G_CALLTITLE=""
G_RCVPORT=11112

# For Mac OS X Darwin with MacPorts
if [[ -f /opt/local/lib/dicom.dic ]] ; then
    export DCMDICTPATH=/opt/local/lib/dicom.dic
fi

G_SYNOPSIS="

  NAME

        pacs_pull.bash

  SYNOPSIS
  
        pacs_pull.bash  -M <MRN> || -N <PatientsName>                   \\
			[-m <modality>]					\\
                        [-R]                                            \\
                        [-D <scandate>]                                 \\
                        [-S <seriesDescription>]                        \\
			[-h <institution>]				\\
                        [-a <aetitle>]                                  \\
                        [-P <PACShost>]                                 \\
                        [-p <PACSport>]                                 \\
			[-c <calltitle>]				\\
                        [-v <verbosityLevel>]

  DESC

        'pacs_pull.bash' queries and pulls studies of interest from a 
        PACS, pulling DICOM data to <calltitle>:<localPort>.

        It is usually driven by specifying an MRN, with an optional <scandate>
        and <seriesDescription>. If all three tags are specified, a single
        series is requested. If the <seriesDescription> is omitted, then
        all series corresponding to the <MRN> and <scandate> are retrieved.
        If in addition the <scandate> is omitted, then all series on all
        dates are retrieved. If only the <MRN> and <seriesDescription> are
        specified, then only that series but across all available dates
        is retrieved.

  ARGS

        -M <MRN> || -N <PatientsName>
        MRN or patient name to query. Only specify one or the other; if
	both are specified, the <PatientsName> is ignored. Also note that
	the <PatientsName> is an *exact* string -- no substring searching
	is performed. The name is found only if it exactly matches the
	name in the PACS.
	
	Multiple targets can be concatenated with a ',' -- i.e. -M 123,456
	will search for MRN 123 and then MRN 456.
        
	-m <modality>
	The modality to retrieve. This defaults to 'MR'. For CT, use 'CT'.

        -R
        By default, the script will only query the PACS and not retrieve
        images. This behaviour is by design and protects the user from
        accidentally starting a pull operation by mistake. In order to
        actually pull data, specify this flag.
        
        -D <scandate>
        Scan date. If not specified, will collect *all* matches. Use with
        some care.

        -S <seriesDescription>
        Series description. If specified, limit retrieve or query to
        <seriesDescription>. This is a substring search match.

	-h <institution>
        If specified, assigns some default AETITLE and PACS variables
        appropriate to the <institution>. Valid <institutions> are
	'MGH' and 'CHB'.

        -a <aetitle> (Optional $G_AETITLE)
        Local AETITLE. This is the only field that the CHB PACS seems to care 
        about. Queries are retrieved to the host:port that is associated
        with this <aetitle>.
                
	-c <calltitle> (Optional)
	The call title. Required by some, but not all, PACS.

        -P <PACShost> (Optional $G_QUERYHOST)
        The PACS host to query.

        -p <PACSport> (Optional $G_QUERYPORT)
        The port on <PACShost>.        
        
	-v <verbosityLevel> (Optional)
        This script defaults to a verbosityLevel of '1'. To be most
        verbose, use a level of '10'.

  DEPENDS
  o blockSort.py, blockFilter.py, lineAfter.py
  o numpy
        
  HISTORY
    
  20 April 2011
  o Initial design and coding.

  01 June 2011
  o Updates to handle new behaviour of 'findscu' ver 3.6.x --
    all output is now to stderr, and an extra column in output
    data appears as column 1.

"

A_MRN="checking command line args"
A_noBlockSort="performing the block sort"
A_studyFindFail="performing a findscu based search for the study"
A_noMRNorName="looking at the search criteria"

EM_MRN="I couldn't find -M <MRN>. This is a required key.'"
EM_noBlockSort="I couldn't find any sorted series files."
EM_studyFindFail="the PACS replied that the query was malformed."
EM_noMRNorName="I couldn't find either a -M <MRN> or -N <PatientsName>.\n\tYou *must* specify one or the other."

EC_MRN=10
EC_noBlockSort=11
EC_studyFindFail=12
EC_noMRNorName=13

# DICOM tag label
G_QueryRetrieveLevel="0008,0052"
G_PatientsName="0010,0010"
G_SeriesDescription="0008,103e"
G_StudyInstanceUID="0020,000d"
G_SeriesInstanceUID="0020,000e"
G_PatientID="0010,0020"
G_Modality="0008,0060"
G_StudyDate="0008,0020"
G_PatientAge="0010,1010"
G_PatientBirthDate="0010,0030"
G_RetrieveAETitle="0008,0054"
G_ScheduledStudyLocationAETitle="0032,1021"
G_ScheduledStationAETitle="0040,0001"
G_PerformedStationAETitle="0040,0241"

function bracket_find
{
    TEXT=$1
    FIND=$(echo $TEXT | sed -e 's/.*\[\([^]]*\)\].*/\1/g')
    echo $FIND
}

function PACSdata_size
{
  seriesSize=$(/bin/ls -l $G_FINDSCUSERIESSTD | awk '{printf $5}')
  studySize=$(/bin/ls -l $G_FINDSCUSTUDYSTD | awk '{printf $5}')
  cprint "I: Size of Study MetaInfo" "[ $studySize ]"
  cprint "I: Size of Series MetaInfo" "[ $seriesSize ]"
}

function DICOMline_scanFor
{
    line="$1"
    scanFor="$2"
    echo "$line"
    echo "$scanFor"
    FOUND=$(echo "$line"        | grep "$scanFor")
    if (( ${#FOUND} )) ; then
        HIT=$(bracket_find "$FOUND")
        echo $HIT
    fi
}

function moveSERIES_cmd
{
    STUDYIDTOPULL="$1"
    SERIESUIDTOPULL="$2"

    lprint "Starting PACS SERIES retrieve..."

    PULL="movescu  -S --aetitle ${G_AETITLE}                            \
                   --move $G_AETITLE                                    \
                   -k $G_QueryRetrieveLevel=SERIES                      \
                   -k $G_StudyInstanceUID=${STUDYIDTOPULL}              \
                   -k $G_SeriesInstanceUID=$SERIESUIDTOPULL             \
                   $G_QUERYHOST $G_QUERYPORT"

    eval "$PULL"
    rprint "[ $? ]"
    Gb_final=$(( Gb_final || $? ))
}

function moveSTUDY_cmd
{
    STUDYIDTOPULL="$1"
    SERIESTOPULL="$2"

    lprint "Starting PACS STUDY retrieve..."

    PULL="movescu  --aetitle ${G_AETITLE}                               \
                   --move $G_AETITLE                                    \
                   --study                                              \
                   -k $G_QueryRetrieveLevel=STUDY                       \
                   -k $G_StudyInstanceUID=${STUDYIDTOPULL}              \
                   $G_QUERYHOST $G_QUERYPORT"

    eval "$PULL"
    rprint "[ $? ]"
    Gb_final=$(( Gb_final || $? ))
}

function institution_set
{
    local INSTITUTION=$1

    case "$INSTITUTION" 
    in
	CHB)
	  G_AETITLE=rudolphpienaar
	  G_QUERYHOST=134.174.12.21
	  G_QUERYPORT=104
	;;
	CHB-chris)
	  G_AETITLE=FNNDSC-CHRIS
	  G_QUERYHOST=134.174.12.21
	  G_QUERYPORT=104
	;;
	CHB-chrisdev)
	  G_AETITLE=FNNDSC-CHRISDEV
	  G_QUERYHOST=134.174.12.21
	  G_QUERYPORT=104
	;;
	CHB-christest)
	  G_AETITLE=FNNDSC-CHRISTEST
	  G_QUERYHOST=134.174.12.21
	  G_QUERYPORT=104
	;;
	MGH)
	  G_AETITLE=ELLENGRANT
	  G_QUERYHOST=172.16.128.91
	  G_QUERYPORT=104
	  G_CALLTITLE=SDM1
	;;
	MGH2)
	  G_AETITLE=ELLENGRANT-CH
	  G_QUERYHOST=172.16.128.91
	  G_QUERYPORT=104
	  G_CALLTITLE=SDM1
	;;
    esac
}

while getopts M:N:m:QD:S:a:c:l:P:p:v:Rh: option ; do
    case "$option" 
    in
        v) Gi_verbose=$OPTARG           ;;
        M) GLST_PATIENTID=$OPTARG       ;;
	m) G_MODALITY=$OPTARG		;;
	N) GLST_PATIENTSNAME=$OPTARG	;;
        R) let Gb_queryOnly=0           ;;
        D) G_SCANDATE=$OPTARG           ;;
        S) G_SERIESDESCRIPTION=$OPTARG
           let Gb_seriesRetrieve=1      ;;
	h) G_INSTITUTION=$OPTARG
	   let Gb_institution=1		;;
        a) G_AETITLE=$OPTARG            ;;
        c) G_CALLTITLE=$OPTARG          ;;
        l) G_RCVPORT=$OPTARG            ;;
        P) G_QUERYHOST=$OPTARG          ;;
        p) G_QUERYPORT=$OPTARG          ;;
        *) synopsis_show                ;;
    esac
done

if (( Gb_institution )) ; then
    institution_set $G_INSTITUTION
fi

if (( ! ${#GLST_PATIENTID} && ! ${#GLST_PATIENTSNAME} )) ; then fatal noMRNorName; fi
if (( ${#GLST_PATIENTID} && ${#GLST_PATIENTSNAME} )) ; then GLST_PATIENTSNAME="" ; fi
if (( ${#G_SCANDATE}            )) ; then Gb_dateSpecified=1;   fi

if (( ${#GLST_PATIENTID} )) ;   then GLST=$GLST_PATIENTID; fi 
if (( ${#GLST_PATIENTSNAME}));  then GLST=$GLST_PATIENTSNAME; fi

for EL in $(echo $GLST | tr , ' '); do
    cprint "M: Institution"		"[ $G_INSTITUTION ]"
    cprint "M: AETitle for query"	"[ $G_AETITLE ]"
    cprint "M: PACS IP"		        "[ $G_QUERYHOST ]"
    cprint "M: CallTitle for query"	"[ $G_CALLTITLE ]"

    if (( ${#GLST_PATIENTID} )) ; then G_PATIENTID=$EL; fi
    if (( ${#GLST_PATIENTSNAME})) ; then G_PATIENTSNAME=$EL; fi

    if (( ${#G_PATIENTID} )) ; then
        cprint "M: Querying for MRN" "[ $G_PATIENTID ]"
    fi

    if (( ${#G_PATIENTSNAME} )) ; then
        cprint "M: Querying for NAME" "[ $G_PATIENTSNAME ]"
    fi

    if (( Gb_dateSpecified )) ; then
        cprint "M: Querying for SCANDATE" "[ $G_SCANDATE ]" 
    else
        cprint "M: Querying for SCANDATE" "[ unspecified ]"
    fi

    # We perform two queries off 'findscu'. The first at the STUDY level
    # collects the StudyInstanceUID. The second, at the SERIES level,
    # collects all the SeriesDescriptions.

    # First, query the PACS for StudyInstanceUID. This is a unique tag, and
    # in this case the combination of MRN:SCANDATE is a unique specifier. If
    # the date is not specified, then multiple StudyInstanceUIDs are returned.
    if (( ${#G_CALLTITLE} )) ; then
        CALLSPEC="--call $G_CALLTITLE"
    fi
    QUERYSTUDY="findscu -xi -S --aetitle $G_AETITLE $CALLSPEC               \
             -k $G_QueryRetrieveLevel=STUDY                                 \
             -k $G_PatientID=$G_PATIENTID                                   \
             -k $G_Modality=$G_MODALITY                                     \
             -k $G_StudyDate=$G_SCANDATE                                    \
             -k $G_PatientsName=$G_PATIENTSNAME                             \
             -k $G_StudyInstanceUID=                                        \
             $G_QUERYHOST $G_QUERYPORT 2> $G_FINDSCUSTUDYSTD"

    QUERY="$QUERYSTUDY"
    lprint "I: Results of 'findscu'"
    eval "$QUERY"
    ret_check $? || fatal studyFindFail
    #echo "$QUERY"
    UILINE=$(cat $G_FINDSCUSTUDYSTD| grep StudyInstanceUID)
    #echo "UILINE=$UILINE"
    UI=$(echo "$UILINE" | awk '{print $4}')
    #echo "UI=$UI"

    statusPrint "" "\n"

    # Now collect the Series information
    rm -f $G_FINDSCUSERIESSTD
    #rm -f $G_FINDSCUSERIESERR
    if (( ${#UI} )) ; then
      printf "I: StudyInstanceUID hits:\n"
      for currentUIb in $UI ; do
        currentUI=$(bracket_find $currentUIb)
        statusPrint "I: Collecting series information for $currentUI" "\n"
        QUERYSERIES="findscu -v -S --aetitle $G_AETITLE $CALLSPEC		\
             -k $G_QueryRetrieveLevel=SERIES                                \
             -k $G_PatientID=$G_PATIENTID                                   \
             -k $G_Modality=$G_MODALITY                                     \
             -k $G_StudyDate=$G_SCANDATE                                    \
             -k $G_PatientsName=$G_PATIENTSNAME                             \
             -k $G_PatientBirthDate=                                        \
             -k $G_StudyInstanceUID=$currentUI                              \
             -k $G_SeriesInstanceUID=                                       \
             -k $G_SeriesDescription=                                       \
             $G_QUERYHOST $G_QUERYPORT 2>> $G_FINDSCUSERIESSTD"
        eval "$QUERYSERIES"
        #echo "$QUERYSERIES"
      done
      echo ""
      PACSdata_size    
    else
      echo ""
      statusPrint "No hits returned for MRN $G_PATIENTID."
      echo ""
      shut_down 1
    fi

    lprint "I: Cleaning Series MetaInfo"
    cp $G_FINDSCUSERIESSTD $G_FINDSCUSERIESSTD.bak
    blockFilter.py -f $G_FINDSCUSERIESSTD.bak -s Unknown -u Dicom-Data > $G_FINDSCUSERIESSTD
    rm $G_FINDSCUSERIESSTD.bak
    rprint "[ ok ]"
    lprint "I: Filtering down UI list"
    UILINE=$(cat $G_FINDSCUSERIESSTD| grep StudyInstanceUID | uniq)
    UI=$(echo "$UILINE" | awk '{print $4}')
    rprint "[ ok ]"
    lprint "I: Sorting UI series files"
    blockSort.py -f $G_FINDSCUSERIESSTD -s Dicom-Data -u ---- -S StudyInstanceUID -C 4
    rprint "[ ok ]"
    lprint "I: Reordering UI series files"
    HITS=$(/bin/ls -1 $G_FINDSCUSERIESSTD.* 2>/dev/null | wc -l)
    if (( !HITS )) ; then fatal noBlockSort ; fi
    for FILE in $G_FINDSCUSERIESSTD.* ; do
        LINE="lineAfter.py -f $FILE -s StudyInstance -u SeriesInstance > ${FILE}.reordered"
        #echo "$LINE"
        eval "$LINE"
        mv ${FILE}.reordered $FILE
    done
    rprint "[ ok ]"
    PACSdata_size
    echo ""

    if (( Gi_verbose == 10 )) ; then
        echo -e "QUERYSERIES: "
        echo $QUERYSERIES
        cat $G_FINDSCUSERIESSTD
    fi
    Gb_final=$(( Gb_final || $? ))

    b_dateHit=0
    for currentUIb in $UI ; do
      currentUI=$(bracket_find $currentUIb)
      echo ""
      statusPrint "I: StudyInstanceUID = $currentUI:" "\n"
      Gb_metaInfoPrinted=0
      SERIESFILE=${G_FINDSCUSERIESSTD}.${currentUI}
      IFS=$'\n'
      while read line ; do
        DA=$(echo "$line" | grep "0008,0020")
        if (( ${#DA} )) ; then
            STUDYDATE=$(bracket_find "$DA")
            if (( !Gb_dateSpecified )) ; then
                b_dateHit=1
            elif [[ $G_SCANDATE == $STUDYDATE ]] ; then
                b_dateHit=1
            fi
        fi
        UILINE=$(echo "$line"       | grep "$G_StudyInstanceUID")
        STUDYUID=$(bracket_find "${UILINE}")

        tBIRTHDATE=$(echo "$line"   | grep "$G_PatientBirthDate")
        if (( ${#tBIRTHDATE} ));then BIRTHDATE=$(bracket_find "$tBIRTHDATE"); fi

        tNAME=$(echo "$line"        | grep "$G_PatientsName")
        if (( ${#tNAME} )) ; then NAME=$(bracket_find "$tNAME");    fi

        tMRID=$(echo "$line"        | grep "$G_PatientID")
        if (( ${#tMRID} )) ; then G_PATIENTID=$(bracket_find "$tMRID");    fi
        
        tSERIESUID=$(echo "$line"   | grep "$G_SeriesInstanceUID")
        if (( ${#tSERIESUID} )) ; then
            SERIESUID=$(bracket_find "$tSERIESUID");
            b_seriesUIDOK=1
        fi

        tSERIES=$(echo "$line"      | grep "$G_SeriesDescription")
        if (( ${#tSERIES} )) ; then
            SERIES=$(bracket_find "$tSERIES")
            b_seriesOK=$(echo "$SERIES" | grep -v "no value" | wc -l)
            if (( Gb_seriesRetrieve )) ; then
                b_seriesOK=$(echo "$SERIES"|grep "$G_SERIESDESCRIPTION"|wc -l)
            fi
        fi
        if [[   ${STUDYUID} == $currentUI   &&              \
                $b_dateHit == 1             &&              \
                $b_seriesOK == 1            &&              \
                $b_seriesUIDOK == 1 ]] ; then
            if (( !Gb_metaInfoPrinted )) ; then
                cprint "Scan Date"          "$STUDYDATE"
                cprint "Patient Name"       "$NAME"
                cprint "Patient MRN"        "$G_PATIENTID"
                cprint "Patient Birthdate"  "$BIRTHDATE"
                cprint "Patient Age"        "$(age_calc.py $BIRTHDATE $STUDYDATE 2>/dev/null)"
                echo ""
                Gb_metaInfoPrinted=1
                if (( !Gb_queryOnly && !Gb_seriesRetrieve )) ; then
                    moveSTUDY_cmd $STUDYUID;
                fi
            fi
            cprint "SeriesDescription" "$SERIES"
            #cprint "SeriesUID" "$SERIESUID"
            if (( !Gb_queryOnly && Gb_seriesRetrieve )) ; then
                moveSERIES_cmd $STUDYUID "$SERIESUID";
            fi
            b_dateHit=0
            b_seriesUIDOK=0
        fi
        done < ${G_FINDSCUSERIESSTD}.${currentUI}
    done
    printf "\n"
    # rm $G_FINDSCUSTUDYERR
    rm $G_FINDSCUSTUDYSTD
    # rm $G_FINDSCUSERIESERR
    rm $G_FINDSCUSERIESSTD
    rm $G_FINDSCUSERIESSTD.*
done
exit $Gb_final



