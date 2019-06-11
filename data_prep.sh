#! /bin/bash 

corpus=${1:-"data/corpus"}
numspk=${2-2}
data=${3:-"data"}

rm -f $data/wav.scp
rm -f $data/reco2num_spk
rm -f $data/utt2spk

for wav in $corpus/*; do
    uttID=$(basename $wav)
    uttID=${uttID%".wav"}

    format=$(file $wav | cut -d, -f 3 | cut -d ' ' -f 3)
    echo "$uttID.wav : $format"
    if [ "$format" == "PCM" ]; then
        echo "$uttID $wav" >> $data/wav.scp
    else
        echo "$uttID ffmpeg -v 8 -i $wav -f wav -acodec pcm_s16le -|" >> $data/wav.scp
    fi 
    echo "$uttID $numspk" >> $data/reco2num_spk
    echo "$uttID $uttID" >> $data/utt2spk 
done

./utils/utt2spk_to_spk2utt.pl $data/utt2spk > $data/spk2utt
./utils/validate_data_dir.sh --no-feats --no-text $data 
./utils/fix_data_dir.sh $data
