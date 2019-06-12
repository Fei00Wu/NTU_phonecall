#!/bin/bash
#Before running this program, pls run: ln -s symbolic_link_source target, in advance. Since I didnt figure out the enviroment variables problem so far...
#--nj i: i files are processing in each time step
#--cmd "run.pl"/"queue.pl"  run in local/server

# Set this to the last stage you used, e.g. stage=3

stage=5

. utils/parse_options.sh
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc
num_spkr=$1
# put audios in ./data/Audio
# results will be saved in ./data/SpeakerDiarization_results
inputdir=data/Audio
outputdir=data/SpeakerDiarization_results

# create temporary forlder ./data/tmp to run speaker diarization model
datadir=data/tmp
logdir=data/tmp/log
nnet_dir=xvector_nnet_1a_ntu/

SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

mkdir -p $SCRIPTPATH/$outputdir
mkdir -p $SCRIPTPATH/$datadir


# Stage 0, prepare the data directory
if [ $stage -le 0 ]; then
  bash ./data_preparation.sh $SCRIPTPATH/$inputdir $num_spkr $datadir
  utils/fix_data_dir.sh $datadir
fi

# Stage 1, make MFCCs, frame-level VAD decisions, and segments
if [ $stage -le 1 ]; then
  #downsample input_audio -r target_freq output_audio
  #Make mfcc feature for audio
  #$1:data $2:logdir $3:mfccdir(if exist, or $1/data)
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 1 \
    --cmd "run.pl" --write-utt2num-frames true \
    $datadir $logdir/mfcclog $mfccdir
  #TODO? Here missing $mfccdir, corrected
  frame_shift=0.01
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' ${datadir}/utt2num_frames > ${datadir}/utt2dur
  #TODO? utils/fix_data_dir.sh $datadir
  utils/fix_data_dir.sh $datadir

  #utils/fix_data_dir.sh data/test
  #Energy-based vad 
  #$1:data//$2:logdir//$3:vad result dir
  sid/compute_vad_decision.sh --nj 1 --cmd "run.pl" \
    $datadir $logdir/vadlog $vaddir
  #TODO? utils/fix_data_dir.sh $datadir
  utils/fix_data_dir.sh $datadir
  #utils/fix_data_dir.sh data/test
  
  local/nnet3/xvector/prepare_feats.sh --nj 1 --cmd "run.pl"\
   $datadir ${datadir}/mfcc_cmn $logdir/mfcc_cmn_log
  utils/fix_data_dir.sh ${datadir}/mfcc_cmn

  echo "0.01" > ${datadir}/mfcc_cmn/frame_shift
  
  diarization/vad_to_segments.sh --nj 1 --cmd "run.pl"\
   ${datadir}/mfcc_cmn ${datadir}/mfcc_cmn_segmented

  #Transform vad decision to segment file, e.g.: audio1 00:33 02:15
  #$1:data//$2:data_out
  #TODO? maybe remove segmentation-opts?
  #diarization/vad_to_segments.sh --nj 1 --cmd "run.pl"\
  # --segmentation-opts '--silence-proportion 0.2 --max-segment-length 10'\
  # $datadir $datadir/segmentation
fi
#TODO? CMN is usually performed prior to segmentation,
# which is performed on raw mfcc
# I am not sure doing it postly will have bad effect
# Stage 2: Apply CMN to the segmented features
#if [ $stage -le 2 ]; then
  #Apply cmvn to mfcc
  #$1:segments dir//$2:data dir after cmvn//$3:log dir
#  local/nnet3/xvector/prepare_feats.sh --nj 1 --cmd "run.pl"\
#    $datadir/segmentation  $datadir/mfcc_cmn $logdir/mfcc_log
#  cp $datadir/segmentation/segments $datadir/mfcc_cmn
#  utils/fix_data_dir.sh $datadir/mfcc_cmn
#fi

# Stage 3: Extract x-vectors
if [ $stage -le 3 ]; then
  #Extract x-vectors for mfcc of audio
  #$1:nnet paramemter loader dir//$2:dir to load data//$3:x-vectors dir
  diarization/nnet3/xvector/extract_xvectors.sh --cmd "run.pl"\
    --nj 1 --window 1.5 --period 0.75 --apply-cmn false --min-segment 0.5\
    $nnet_dir $datadir/mfcc_cmn_segmented $datadir/xvector
fi

# Stage 4: Compute PLDA scores between all pairs of x-vectors
if [ $stage -le 4 ]; then
  #Extract x-vectors for mfcc of audio
  #PLDA scoring
  #para $1:plda pretrained para//$2:dir for xvector info//$3:dir for plda scores 
  diarization/nnet3/xvector/score_plda.sh --cmd "run.pl"\
   --target-energy 0.1 --nj 1 $nnet_dir/xvectors_callhome1/\
   $datadir/xvector/ $datadir/pldascores
fi

# Stage 5: use agglomerative hierarchical clustering to cluster the pairs of PLDA scores
if [ $stage -le 5 ]; then
  #Clustering by PLDA scoring
  #$1:reconum_spk file's path//$2:dir of plda scores//$3:dir for final result:labels and rttm
  diarization/cluster.sh --cmd "run.pl" --nj 1 --reco2num-spk $datadir/reco2num_spk\
   $datadir/pldascores/ $datadir/diarization_result
fi


#exit 1;

# TODO: stage 6
if [ $stage -le 6 ]; then
# clean existed output folder and move new resuls into the output folder
rm -rf $outputdir
cp -r $datadir/diarization_result $outputdir
#rm -rf $datadir


# create audio files which contain each person's voice 
input=$outputdir/rttm
read -a arr < $input
file_name_fist=${arr[1]}
#echo $file_name_fist

ARRAY=()
for i in $(seq 1 1 $num_spkr)
do
  #echo
  ARRAY+=('')
done
#echo $ARRAY

while IFS= read -r line
do
  #echo "$line"
  stringarray=( $line )
  file_name=${stringarray[1]}
  #echo  $file_name
  starting_timeline=${stringarray[3]}
  ending_timeline=${stringarray[4]}
  ending_timeline=$(awk "BEGIN {print $starting_timeline+$ending_timeline; exit}")
  speaker_id=${stringarray[7]}
  # echo $file_name_fist,$file_name,$starting_timeline,$ending_timeline,$speaker_id >> log 
  if [ "$file_name" == "$file_name_fist" ]; then 
    index=( $(seq 1 1 $num_spkr) )
    index=( "${index[@]:0:$speaker_id-1}" "${index[@]:$speaker_id}" )
    for i in ${index[@]}
    do
      if [ -z "${ARRAY[$i]}" ]
      then
        ARRAY[$i]="${ARRAY[$i]}volume=enable='between(t,$starting_timeline,$ending_timeline)':volume=0"
      else
        ARRAY[$i]="${ARRAY[$i]}, volume=enable='between(t,$starting_timeline,$ending_timeline)':volume=0"
      fi
    done
 
  else
    
    for i in $(seq 1 1 $num_spkr)
    do
      ffmpeg -i $inputdir/$file_name.wav -af "${ARRAY[$i]}" $outputdir/${file_name_fist}_speaker_$i.wav
    done
    
    file_name_fist=$file_name
    ARRAY=()
    for i in $(seq 1 1 $num_spkr)
    do
      ARRAY+=('')
    done

    index=( $(seq 1 1 $num_spkr) )
    index=( "${index[@]:0:$speaker_id-1}" "${index[@]:$speaker_id}" )
    for i in ${index[@]}
    do
      if [ -z "${ARRAY[$i]}" ]
      then
        ARRAY[$i]="${ARRAY[$i]}volume=enable='between(t,$starting_timeline,$ending_timeline)':volume=0"
      else
        ARRAY[$i]="${ARRAY[$i]}, volume=enable='between(t,$starting_timeline,$ending_timeline)':volume=0"
      fi
    done
  fi
done < "$input"


for i in $(seq 1 1 $num_spkr)
do
  ffmpeg -i $inputdir/$file_name.wav -af "${ARRAY[$i]}" $outputdir/${file_name_fist}_speaker_$i.wav
done
fi
