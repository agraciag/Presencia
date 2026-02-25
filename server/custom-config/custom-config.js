// Presencia - Jitsi Meet custom configuration
// Optimized for long-running 2-participant transcontinental calls

config.defaultLanguage = 'es';

// ─── Disable P2P: force all traffic through JVB ────────────────
// P2P can be unstable on long transcontinental calls.
// JVB provides better reliability and easier debugging.
config.p2p = {
    enabled: false
};

// ─── Video quality ─────────────────────────────────────────────
// 720p balances quality and bandwidth for transcontinental links
config.resolution = 720;
config.constraints = {
    video: {
        height: { ideal: 720, max: 720, min: 360 },
        width: { ideal: 1280, max: 1280, min: 640 }
    }
};

// ─── Disable prejoin page ──────────────────────────────────────
// NUC must auto-join without any user interaction
config.prejoinConfig = {
    enabled: false
};

// ─── Auto-join and reliability ─────────────────────────────────
config.startWithAudioMuted = false;
config.startWithVideoMuted = false;
config.enableWelcomePage = false;
config.disableDeepLinking = true;

// Reconnect automatically on network issues
config.enableIceRestart = true;

// ─── Disable unnecessary features ──────────────────────────────
config.disableThirdPartyRequests = true;
config.disableInviteFunctions = true;
config.hideConferenceSubject = true;
config.hideConferenceTimer = false;

// ─── Audio ─────────────────────────────────────────────────────
config.disableAP = false;
config.enableNoisyMicDetection = false;
config.enableNoAudioDetection = true;

// ─── Notifications ─────────────────────────────────────────────
config.notifications = [];
config.disabledNotifications = [
    'dialog.thankYou',
    'dialog.meetingUnlocked',
    'notify.connectedOneMember',
    'notify.leftOneMember',
    'notify.moderationInEffectCS498'
];
