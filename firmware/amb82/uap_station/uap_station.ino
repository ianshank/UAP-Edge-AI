// uap_station.ino — AMB82-Mini firmware for the UAP detection station.
//
// Tier 1 of the three-tier pipeline:
//   AMB82 (this) → UART → Pi 2 (gatekeeper) → WoL+SSH → Pi 5 (capture).
//
// Responsibilities:
//   * Connect to Wi-Fi.
//   * Stream H.264 over RTSP on the standard port (rtsp://<ip>:554).
//   * Run YOLOv4-tiny on the on-chip 0.4 TOPS NPU at 416x416 RGB.
//   * Emit one CSV line per detection over Serial1 at 115200 baud:
//       EVT,<timestamp_ms>,<source>,<score>,<x>,<y>,<w>,<h>,<label>
//
// Wiring (NOT USB — GPIO UART crossover):
//   AMB82 D21 (PA2 / SERIAL1_TX) -> Pi 2 physical pin 10 (GPIO15 / RXD)
//   AMB82 D22 (PA3 / SERIAL1_RX) -> Pi 2 physical pin  8 (GPIO14 / TXD)
//   AMB82 GND                    -> Pi 2 physical pin  6 (GND)
//
// Upload procedure (Arduino IDE 2.x):
//   1. Hold UART_DOWNLOAD on the AMB82.
//   2. Tap RESET.
//   3. Release UART_DOWNLOAD.
//   4. Click Upload in the IDE.
//   (Or enable Tools -> Auto Flash Mode after the first successful upload.)
//
// After upload, open Serial Monitor at 115200 — the board prints its IP on boot.
// Write that IP into pi5/capture_uap.sh as AMB82_RTSP.

#include "WiFi.h"
#include "StreamIO.h"
#include "VideoStream.h"
#include "RTSP.h"
#include "NNObjectDetection.h"
#include "VideoStreamOverlay.h"

#define CHANNEL    0   // H.264 RTSP channel
#define NNCHANNEL  3   // RGB channel feeding the NPU

// ----- Wi-Fi credentials --------------------------------------------------
// Wi-Fi credentials baked in from user input.
char ssid[] = "Mango_Tango";
char pass[] = "N3ll!3_06902";
// --------------------------------------------------------------------------

// Detection threshold. Lower = more events, more noise. Tune in §11 (Field
// tuning) of the build guide. 0.40 is a sane starting point.
const int SCORE_THRESHOLD = 40;  // score() returns 0–100

VideoSetting config(VIDEO_FHD, CAM_FPS, VIDEO_H264, 0);
VideoSetting configNN(416, 416, 10, VIDEO_RGB, 0);

NNObjectDetection ObjDet;
RTSP rtsp;
StreamIO videoStreamer(1, 1);
StreamIO videoStreamerNN(1, 1);

void setup() {
    Serial.begin(115200);    // USB-CDC debug
    Serial1.begin(115200);   // GPIO UART to Pi 2 (D21=TX, D22=RX)

    while (WiFi.begin(ssid, pass) != WL_CONNECTED) {
        Serial.println("WiFi connect retry...");
        delay(2000);
    }
    Serial.print("AMB82 IP: ");
    Serial.println(WiFi.localIP());

    Camera.configVideoChannel(CHANNEL,   config);
    Camera.configVideoChannel(NNCHANNEL, configNN);
    Camera.videoInit();

    rtsp.configVideo(config);
    rtsp.begin();

    ObjDet.configVideo(configNN);
    ObjDet.modelSelect(OBJECT_DETECTION,
                       DEFAULT_YOLOV4TINY,
                       NA_MODEL,
                       NA_MODEL);
    ObjDet.begin();

    videoStreamer.registerInput(Camera.getStream(CHANNEL));
    videoStreamer.registerOutput(rtsp);
    videoStreamer.begin();

    videoStreamerNN.registerInput(Camera.getStream(NNCHANNEL));
    videoStreamerNN.setStackSize();
    videoStreamerNN.setTaskPriority();
    videoStreamerNN.registerOutput(ObjDet);
    videoStreamerNN.begin();

    Camera.channelBegin(CHANNEL);
    Camera.channelBegin(NNCHANNEL);

    Serial.println("UAP station ready.");
}

void loop() {
    unsigned long t = millis();
    std::vector<ObjectDetectionResult> r = ObjDet.getResult();
    int W = config.width(), H = config.height();

    for (auto& d : r) {
        if (d.score() < SCORE_THRESHOLD) continue;

        // Emit one CSV line per detection. The Pi 2 gatekeeper parses these
        // by splitting on ',' and validating exactly 9 fields.
        Serial1.print("EVT,");
        Serial1.print(t);                                 Serial1.print(",YOLO,");
        Serial1.print(d.score());                         Serial1.print(",");
        Serial1.print((int)(d.xMin() * W));               Serial1.print(",");
        Serial1.print((int)(d.yMin() * H));               Serial1.print(",");
        Serial1.print((int)((d.xMax() - d.xMin()) * W));  Serial1.print(",");
        Serial1.print((int)((d.yMax() - d.yMin()) * H));  Serial1.print(",");
        Serial1.println(d.name());
    }
    delay(100);
}
