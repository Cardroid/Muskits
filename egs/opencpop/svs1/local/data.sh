#!/usr/bin/env bash

set -e
set -u
set -o pipefail

. ./path.sh || exit 1;
. ./cmd.sh || exit 1;
. ./db.sh || exit 1;

log() {
    local fname=${BASH_SOURCE[1]##*/}
    echo -e "$(date '+%Y-%m-%dT%H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}

SECONDS=0
stage=1
stop_stage=100
fs=24000

log "$0 $*"

. utils/parse_options.sh || exit 1;

if [ -z "${OPENCPOP}" ]; then
    log "Fill the value of 'OFUTON' of db.sh"
    exit 1
fi

mkdir -p ${OPENCPOP}

train_set=tr_no_dev
train_dev=dev

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    log "stage 0: Data Download"
    # The Opencpop data should be downloaded from https://wenet.org.cn/opencpop/
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    log "stage 1: Data preparaion "

    mkdir -p midi_dump
    mkdir -p wav_dump
    # we convert the music score to midi format
    python local/data_prep.py ${OPENCPOP} --midi_note_scp local/midi-note.scp \
        --midi_dumpdir midi_dump \
        --wav_dumpdir wav_dump \
        --sr ${fs}
    for src_data in train test; do
        utils/utt2spk_to_spk2utt.pl < data/${src_data}/utt2spk > data/${src_data}/spk2utt
        utils/fix_data_dir.sh --utt_extra_files "label midi.scp" data/${src_data}
    done
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    log "stage 2: Held out validation set"
    
    scripts/utils/copy_data_dir.sh data/train data/tr_no_dev
    scripts/utils/copy_data_dir.sh data/train data/dev
    tail -n 50 data/train/wav.scp > data/dev/wav.scp
    utils/filter_scp.pl --exclude data/dev/wav.scp data/train/wav.scp > data/tr_no_dev/wav.scp

    utils/fix_data_dir.sh --utt_extra_files "label midi.scp" data/tr_no_dev
    utils/fix_data_dir.sh --utt_extra_files "label midi.scp" data/dev
    
fi
