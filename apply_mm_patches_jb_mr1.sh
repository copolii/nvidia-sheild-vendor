#!/bin/bash

if [ a$GERRIT_USER == a ]; then
  export GERRIT_USER=$USER
fi

#directory, patchname
function apply_patch {
    echo === Changing to $TOP/$1 to apply patch
    pushd $TOP/$1
    echo === git am $TOP/vendor/nvidia/build/$2
    git am $TOP/vendor/nvidia/build/$2
    if [ $? != 0 ]; then
        echo === error: Applying patch failed!
        echo === Aborting!
        echo === Restoring original directory
        popd
        exit 1
    fi
    echo === Restoring original directory
    popd
}


if [ a$TOP == a ]; then
  echo \$TOP is not set. Please set \$TOP before running this script
else
  echo Cherry-picking changes needed for JB-MR1-MM stability
  echo ============================================
  echo ======= frameworks/av MM Patches ===========
  echo ============================================
  pushd $TOP/frameworks/av
  #====================== Frameworks ================================
  apply_patch  frameworks/av ./mm/0001-SF-G711Dec-Support-higher-sample-rates.patch
  apply_patch  frameworks/av ./mm/0002-mp4-parser-integrations-to-JB.patch
  apply_patch  frameworks/av ./mm/0003-libstagefright-Enable-ASF-extractor-in-JB.patch
  apply_patch  frameworks/av ./mm/0004-libstagefright-Enable-Nvidia-AVI-extractor-in-JB.patch
  apply_patch  frameworks/av ./mm/0005-StageFright-MPEG-TS-integrations-to-Android-J.patch
  apply_patch  frameworks/av ./mm/0006-TSParser-Enable-Duration-Seek-VC1-AC3-LPCM-AVCHD-med.patch
  apply_patch  frameworks/av ./mm/0007-StageFright-Enable-NuCachedSource2-for-local-playbac.patch
  apply_patch  frameworks/av ./mm/0008-StageFright-Clears-some-mpeg2-dec-specific-hacks.patch
  apply_patch  frameworks/av ./mm/0009-StageFright-Protect-concurrent-file-reads-between-WV.patch
  apply_patch  frameworks/av ./mm/0010-Implemented-Range-attribute-parsing.patch
  apply_patch  frameworks/av ./mm/0011-Implement-PLAY-start-Range.patch
  apply_patch  frameworks/av ./mm/0012-integrated-mpeg2-ps-from-ICS-to-JB.patch
  apply_patch  frameworks/av ./mm/0013-libstagefright-Integration-to-Android-JB.patch
  apply_patch  frameworks/av ./mm/0014-Stagefright-Add-changes-for-Dynamic-Resolution-chang.patch
  apply_patch  frameworks/av ./mm/0015-Implement-Streaming-KPI-code-PROFILING.patch
  apply_patch  frameworks/av ./mm/0016-Add-profiling-option-in-AwesomePlayer.patch
  apply_patch  frameworks/av ./mm/0017-StagefrightMetadataRetriever-Release-MediaExtractor-.patch
  apply_patch  frameworks/av ./mm/0018-libstagefright-ULP-and-other-misc-MMFW-changes.patch
  apply_patch  frameworks/av ./mm/0019-Send-CSD-data-if-discontinuity.patch
  apply_patch  frameworks/av ./mm/0020-Integrate-Streaming-KPI-to-JB.patch
  apply_patch  frameworks/av ./mm/0021-Consume-data-if-prefetcher-is-stopped.patch
  apply_patch  frameworks/av ./mm/0022-Revert-For-an-RTSP-live-stream-we-won-t-map-rtp-time.patch
  apply_patch  frameworks/av ./mm/0023-HTTP-RTSP-Integrations-to-Android-J.patch
  apply_patch  frameworks/av ./mm/0024-Fix-RTSP-random-crashes.patch
  apply_patch  frameworks/av ./mm/0025-OMXCodec-stop-source-if-codec-init-fails.patch
  apply_patch  frameworks/av ./mm/0026-OggExtractor-Use-last-granule-position-for-local-sou.patch
  apply_patch  frameworks/av ./mm/0027-libstagefright-Increased-the-fragments-value-in-i-p-.patch
  apply_patch  frameworks/av ./mm/0028-libstagefright-Handle-unsupported-codec-metaData.patch
  apply_patch  frameworks/av ./mm/0029-fix-for-crash-in-SimplePlayer.patch
  apply_patch  frameworks/av ./mm/0030-stagefright-Publish-audio-channel-mapping-to-android.patch
  apply_patch  frameworks/av ./mm/0031-libstagefright-Handled-EOS-in-audio-streams-which-ha.patch
  apply_patch  frameworks/av ./mm/0032-libstagefright-handled-EOS-in-different-scenarios.patch
  apply_patch  frameworks/av ./mm/0033-libstagefright-extended-the-buffer-size-of-avcC.patch
  apply_patch  frameworks/av ./mm/0034-MPEGTSExtractor-Optimize-reads-for-local-ts-playback.patch
  apply_patch  frameworks/av ./mm/0035-WAVExtractor-Support-24-bit-format.patch
  apply_patch  frameworks/av ./mm/0036-NuCachedSource2-Turn-off-cache-if-miss-rate-high.patch
  apply_patch  frameworks/av ./mm/0037-NuCachedSource2-Add-delay-b-w-continuous-fetches.patch
  apply_patch  frameworks/av ./mm/0038-stagefright-Set-PCM-audio-output-format-based-on-bit.patch
  apply_patch  frameworks/av ./mm/0039-stagefright-Ignore-Port-Settings-changed-if-de-init.patch
  apply_patch  frameworks/av ./mm/0040-SF-Matroska-Support-seek-to-audio-only-file-in-mkv.patch
  apply_patch  frameworks/av ./mm/0041-stagefright-MVC-support-on-JB.patch
  apply_patch  frameworks/av ./mm/0042-RTSP-Streaming-Send-poke-packets-after-long-time-pau.patch
  apply_patch  frameworks/av ./mm/0043-HTTP-Live-Fetch-another-playlist-when-current-fetch-.patch
  apply_patch  frameworks/av ./mm/0044-Stagefright-Fix-ANR-issue-in-case-of-corrupted-m2ts-.patch
  apply_patch  frameworks/av ./mm/0045-libstagefright-solution-for-seamless-DRC.patch
  #=============================== ULP MMFW Changes ====================================
  # CAUTION:XXX Enable only with audio (audioflinger/libaudio) changes (Commit: 162276)
  apply_patch frameworks/av ./mm/0046-frameworks-av-ULP-Audio-changes-in-MMFW.patch
  #=============================== DTS Passthru MMFW changes ===========================
  # CAUTION:XXX Enable only with audio (audioflinger/libaudio) changes
  apply_patch  frameworks/av ./mm/0047-support-AC3-DTS-pass-through-in-JB.patch
  apply_patch  frameworks/av ./mm/0048-SF-Streaming-Abort-if-timestamp-rollover-happens.patch
  apply_patch  frameworks/av ./mm/0049-SF-Streaming-Trigger-reconnect-if-needed.patch
  apply_patch  frameworks/av ./mm/0050-libmediaplayerservice-Support-software-encoders.patch
  apply_patch  frameworks/av ./mm/0051-mpeg-ps-search-for-next-packet-start-code.patch
  apply_patch  frameworks/av ./mm/0052-libstagefright-Allow-other-H264-profiles-for-encoder.patch
  apply_patch  frameworks/av ./mm/0053-stagefright-fix-crash-when-mFileSource-is-NULL.patch

  #=============================== MKV Parser Changes ====================
  # Due to too many ctrl M chars, git am fails for below patch, instead manually cherry
  # pick following for enabling mkv
  # git fetch ssh://sureshc@git-master.nvidia.com:12001/android/platform/external/libvpx refs/changes/89/114389/1 && git cherry-pick FETCH_HEAD
  # git fetch ssh://sureshc@git-master.nvidia.com:12001/android/platform/external/libvpx refs/changes/52/118552/1 && git cherry-pick FETCH_HEAD

  #=============================== DO NOT SUBMIT =========================================
  #=============================== Test patch just to enable asf/avi =====================
  #=============================== Uncomment to build ====================================
  #apply_patch vendor/nvidia/tegra/multimedia-partner/android ./mm/0001-nvparser-Enable-testing-of-avi-asf-media.patch
  popd
fi
