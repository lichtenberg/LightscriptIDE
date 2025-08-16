#ifndef _PICOPROTOCOL_H_
#define _PICOPROTOCOL_H_

#define PICOLIGHT_PROTOCOL_VERSION      2

// Board types

#define PICOHW_TYPE_PICOLIGHT   0
#define PICOHW_TYPE_PICOLASER   1

// Constants shared with the firmware

#define MAXPSTRIPS      16
#define MAXVSTRIPS      128
#define MAXSUBSTRIPS    16

#define PSTRIP_TYPE_GRB        0
#define PSTRIP_TYPE_RGB        1
#define PSTRIP_TYPE_LASER      2

// Physical strip encoding, 31 bits:     0TTT PPPP 0000 0000 0000 LLLL LLLL LLLL
// Max physical strip length is therefore:  4096 LEDs.  This had better be enough.
#define ENCODEPSTRIP(chan, type, count) (((unsigned int) (type) << 28) | ((unsigned int) (chan) << 24) | ((unsigned int) (count) << 0))
#define PSTRIP_COUNT(val) ((val) & 0xFFF)
#define PSTRIP_CHAN(val) (((val) >> 24) & 0xF)
#define PSTRIP_TYPE(val) (((val) >> 28) & 0x7)

// Substrip encoding, 31 bits:  0FFF PPPP SSSS SSSS SSSS CCCC CCCC CCCC
// Max 4096 LEDs per substrip, similar to above.
#define SUBSTRIP_REVERSE        0x01
#define SUBSTRIP_EOT            0x04
#define ENCODESUBSTRIP(pstrip, start, count, flags) \
    (((unsigned int) (flags) << 28) | ((unsigned int) (pstrip) << 24) | ((unsigned int) (start) << 12) |  ((unsigned int) count))
#define SUBSTRIP_FLAGS(x) (((x) >> 28) & 0x0F)
#define SUBSTRIP_CHAN(x) (((x) >> 24) & 0xF)
#define SUBSTRIP_START(x) (((x) >> 12) & 0xFFF)
#define SUBSTRIP_COUNT(x) (((x) >> 0) & 0xFFF)
#define SUBSTRIP_DIRECTION(x) (SUBSTRIP_FLAGS(x) & SUBSTRIP_REVERSE)
#define SUBSTRIP_ISEOT(x) (SUBSTRIP_FLAGS(x) & SUBSTRIP_EOT)



    

// Command codes:   Bit 7 set means we expect to hear a response from the
// firmware.

#define LSCMD_ANIMATE           0               // Send an animation command
#define LSCMD_BRIGHTNESS        1               // Send a global brightness command
#define LSCMD_IDLE              2               // Idle the panel

#define LSCMD_VERSION           0x80            // Firmware version
#define LSCMD_STATUS            0x81            // Return info about current setup
#define LSCMD_RESET             0x82            // Reset and clear configuration
#define LSCMD_SETPSTRIP         0x83            // Set a physical strip
#define LSCMD_SETVSTRIP         0x84            // Set a virtual strip
#define LSCMD_INIT              0x85            // Initialize with programmed parameters.
#define LSCMD_EEPROM            0x86            // EEPROM
#define LSCMD_DFU               0x87            // DFU

typedef struct __attribute__((packed)) lsanimate_s {
    uint16_t    la_anim;
    uint16_t    la_speed;
    uint16_t    la_option;
    uint32_t    la_color;
    uint32_t    la_strips[MAXVSTRIPS/32];
} lsanimate_t;

typedef struct __attribute__((packed)) lsversion_s {
    uint8_t lv_protocol;
    uint8_t lv_major;
    uint8_t lv_minor;
    uint8_t lv_hwtype;
} lsversion_t;

typedef struct __attribute__((packed)) lsstatus_s {
    uint32_t ls_status;
} lsstatus_t;

typedef struct __attribute__((packed)) lspstrip_s {
    uint32_t lp_pstrip;
} lspstrip_t;

typedef struct __attribute__((packed)) lsvstrip_s {
    uint16_t lv_idx;
    uint16_t lv_count;
    uint32_t lv_substrips[MAXSUBSTRIPS];
} lsvstrip_t;

#define LSEEPROM_GETENV 0
#define LSEEPROM_SETENV 1
#define LSEEPROM_PRINTENV 2
#define LSEEPROM_ERASEALL 3
#define LSEEPROM_MAXDATA 251
typedef struct __attribute__((packed)) lseeprom_s {
    uint8_t le_subcmd;
    uint8_t le_data[LSEEPROM_MAXDATA];
} lseeprom_t;

#define LSMSG_HDRSIZE   2
typedef struct __attribute__((packed)) lsmessage_s {
    uint8_t     ls_command;             // command code
    uint8_t     ls_length;              // number of bytes of payload
    union {                             // payload
        lsanimate_t ls_animate;
        lsversion_t ls_version;
        lsstatus_t ls_status;
        lspstrip_t ls_pstrip;
        lsvstrip_t ls_vstrip;
        lseeprom_t ls_eeprom;
    } info;
} lsmessage_t;

#endif
