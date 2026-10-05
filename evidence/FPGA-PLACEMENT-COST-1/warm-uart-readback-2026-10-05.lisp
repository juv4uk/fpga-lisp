; FPGA-PLACEMENT-COST-1 — physical warm UART/readback evidence.
; Date: 2026-10-05. Mechanism evidence only; this file does not define SENS semantics
; and does not set an automatic placement threshold.
(fpga-placement-cost/v1
  (issue . 58)
  (status . physical-measured)
  (device . "Tang Primer 25K / GW5A-25A")
  (transport . ((kind . uart-ft2232-channel-b)
                (port . "COM4")
                (baud . 115200)
                (host . "native-windows-python-pyserial")))
  (resident-image
    . ((program-observation . "bootstrap_add_demo resident/halted image")
       (expected-r9-raw . #x00000007)
       (expected-error-status . #x00000000)
       (reset-during-probe . no)
       (upload-during-probe . no)))
  (persistent-open
    . ((samples . 300)
       (failures . 0)
       (r9-query-ns
        . ((min . 864500)
           (p50 . 1009450)
           (p95 . 4173100)
           (p99 . 6465800)
           (mean . 1569874)
           (max . 9341300)))
       (error-query-ns
        . ((min . 744000)
           (p50 . 1007050)
           (p95 . 3448700)
           (p99 . 9331800)
           (mean . 1454324)
           (max . 10813900)))
       (r9-plus-error-pair-ns
        . ((min . 1855200)
           (p50 . 2026750)
           (p95 . 7253500)
           (p99 . 12047900)
           (mean . 3024198)
           (max . 13228200)))
       (mean-pairs-per-second-x1000 . 330666)))
  (open-query-close
    . ((attempts . 80)
       (successful-samples . 79)
       (failures . 1)
       (r9-query-total-ns
        . ((min . 107089400)
           (p50 . 111830600)
           (p95 . 139173100)
           (p99 . 216386200)
           (mean . 119654918)
           (max . 219182800)))))
  (interpretation
    . ((persistent-serial-ownership . strongly-preferred)
       (median-open-close-over-persistent-pair-ratio-x1000 . 55178)
       (tail-latency . measured-noisy)
       (automatic-placement . blocked)
       (reason . "cold upload/reset/execution cost and comparable CPU/CUDA rows still required"))))
