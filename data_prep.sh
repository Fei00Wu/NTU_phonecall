#! /bin/bash 

corpus=${1:-"data/corpus"}
data=${2:-"data"}

rm -f $data/wav.scp
rm -f $data/reco2num_spk
rm -f $data/utt2spk

for wav in $corpus/*; do
    uttID=$(basename $wav)
    uttID=${uttID%".wav"}
    echo "$uttID $wav" >> $data/wav.scp 
    echo "$uttID 2" >> $data/reco2num_spk
    echo "$uttID $uttID" >> $data/utt2spk 
done
