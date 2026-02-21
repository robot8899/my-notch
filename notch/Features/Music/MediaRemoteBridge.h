#ifndef MediaRemoteBridge_h
#define MediaRemoteBridge_h

// Command constants
typedef enum : int {
    kMRCommandPlay = 0,
    kMRCommandPause = 1,
    kMRCommandTogglePlayPause = 2,
    kMRCommandStop = 3,
    kMRCommandNextTrack = 4,
    kMRCommandPreviousTrack = 5,
} MRCommand;

#endif /* MediaRemoteBridge_h */
