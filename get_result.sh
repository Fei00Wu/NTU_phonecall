#! /bin/bash 
rttm=${1:-"data/SpeakerDiarization_results/rttm"}
out_dir=${2:-"data/SpeakerDiarization_results"}
data_dir=${3:-"data/tmp"}
num_spk=${4:-2}

set -euo
rttm_dir=$data_dir/rttm_tmp
inter_res=$data_dir/res_tmp

stage=0
if [ $stage -le 0 ]; then
    rm -rf $rttm_dir
    mkdir $rttm_dir
    rm -rf $inter_res
    mkdir $inter_res
    cut -d' ' -f1 "$data_dir/wav.scp" > $data_dir/utts_list

    while read line; do
        # Cut rttm into small files based on the utterance ID
        grep $line $rttm > "$rttm_dir/$line.rttm"
    done < $data_dir/utts_list
fi
if [ $stage -le 1 ]; then
    for utt_rttm in $rttm_dir/*;do 
        uttID=$(basename $utt_rttm)
        uttID=${uttID%".rttm"}
        prefix="$rttm_dir/${uttID}_speaker_"
        awk -F' ' -v prefix="$prefix" '{
        file=prefix$8; 
        print $0 > file
    }' $utt_rttm
    done
    rm $rttm_dir/*.rttm
fi

if [ $stage -le 2 ]; then
    for utt_rttm in $rttm_dir/*; do
        file_name=$(basename $utt_rttm)
        uttID=$(basename $utt_rttm | cut -d'_' -f1)
        audio=$(grep $uttID $data_dir/wav.scp | cut -d' ' -f2-)
        end_point=$(soxi -D $audio)
        start_flag=1
        pre_end="0.000"
        while read line; do
            toks=( $line )
            start_t=${toks[3]}
            dur=${toks[4]}
            end_t=$(awk "BEGIN {print $start_t+$dur; exit}")
            
            if [ "$pre_end" != "$start_t" ];then
                if [ "$start_flag" == "1" ]; then
                    echo -n "volume=enable='between(t,$pre_end,$start_t)':volume=0" \
                        >> $rttm_dir/$file_name.seg 
                    start_flag=0
                else
                    echo -n ", volume=enable='between(t,$pre_end,$start_t)':volume=0" \
                        >> $rttm_dir/$file_name.seg
                fi
            fi
            pre_end=$end_t
        done < $utt_rttm
        if [ "$pre_end" != "$end_point" ]; then
            echo -n ", volume=enable='between(t,$pre_end,$end_point)':volume=0" \
                >> $rttm_dir/$file_name.seg
        fi
    done

fi

if [ $stage -le 3 ]; then
    for seg in $rttm_dir/*.seg;do
        sections=$(<$seg)
        outfile=$(basename $seg)
        outfile=${outfile%".seg"}
        uttID=$(echo $outfile | cut -d'_' -f1)
        audio=$(grep $uttID $data_dir/wav.scp | cut -d' ' -f2-)
        echo "ffmpeg -i $audio -af $sections $out_dir/$uttID.wav"
        ffmpeg -i $audio -af "$sections" $out_dir/$outfile.wav
        wait
    done
fi
