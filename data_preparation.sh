#! /bin/bash 
# Data prepareation for NTU phone calls
# Copyright     2019    Fei Wu
#
# Usaege:
# ./data_preparation.sh <path to audios> <num_of_spkrs> <data directory>
# E.g.(default):
# ./data_preparation.sh data/Audio 2 data/tmp

echo "$0 $@"

corpus=${1:-"data/Audio"}
numspk=${2:-2}
data=${3:-"data/tmp"}
mkdir -p $data

tmp_audio=$data/tmp_audio
rm -rf $tmp_audio
mkdir $tmp_audio

./file_check.sh $data

for wav in $corpus/*; do
    uttID=$(basename $wav)
    uttID=${uttID%".wav"}

    format=$(file $wav | cut -d, -f 3 | cut -d ' ' -f 3)
    echo "$uttID.wav : $format"
    if [ "$format" == "PCM" ]; then
        echo "$uttID $wav" >> $data/wav.scp
    else
        ffmpeg -v 8 -i $wav -f wav -acodec pcm_s16le $tmp_audio/$uttID.wav
        echo "$uttID $tmp_audio/$uttID.wav" >> $data/wav.scp
    fi 
    echo "$uttID $numspk" >> $data/reco2num_spk
    echo "$uttID $uttID" >> $data/utt2spk 
done

./utils/utt2spk_to_spk2utt.pl $data/utt2spk > $data/spk2utt
./utils/validate_data_dir.sh --no-feats --no-text $data 
./utils/fix_data_dir.sh $data
